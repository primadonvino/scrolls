import {
  badRequest,
  currentUserId,
  isFounderUserID,
  json,
  mapUser,
  notFound,
  optionsResponse,
  serverError,
  setLogAccountScope,
  setLogAuthUser,
  serviceClient,
  unauthorized,
  withRequestLogging,
  type AppUser,
  type RequestLogContext,
} from '../_shared/http.ts';
import { resolveScopedAccountID } from '../_shared/account_scope.ts';
import { hasMutualBlock, isValidSafetyReportReason, mutuallyBlockedUserIDs, normalizeReportNotes, normalizeReportReason } from '../_shared/safety.ts';
import { fetchUsersByIds } from '../_shared/mappers.ts';

const CLOUDFLARE_ACCOUNT_ID = (Deno.env.get('CLOUDFLARE_ACCOUNT_ID') ?? '').trim();
const CLOUDFLARE_API_TOKEN = (Deno.env.get('CLOUDFLARE_API_TOKEN') ?? '').trim();
const CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN = (Deno.env.get('CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN') ?? '').trim();
const TITLE_MAX_CHARS = 120;
const LIVE_COMMENT_MAX_CHARS = 280;
const LIVE_COMMENT_FETCH_LIMIT_MAX = 120;
const DESCRIPTION_MAX_CHARS = 500;
const GOLD_SUBSCRIPTION_IDS = new Set(['02', 'scrolls.gold.monthly']);
const MOBILE_HEARTBEAT_STALE_MS = 75_000;
const IDEMPOTENCY_KEY_MAX_CHARS = 180;
const VIEWER_PASSWORD_MAX_CHARS = 128;
const VIEWER_PASSWORD_PBKDF2_ITERATIONS = 150_000;
const VIEWER_PASSWORD_VERIFY_LIMIT = 10;
const VIEWER_PASSWORD_VERIFY_WINDOW_MS = 60_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const RADIO_BROADCASTER_IDS = new Set(
  (Deno.env.get('APOLLO_RADIO_BROADCASTER_IDS') ?? '')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean),
);

const viewerPasswordAttempts = new Map<string, { count: number; resetAt: number }>();

type CloudflareLiveInput = {
  streamKey: string;
  ingestURL: string;
  playbackURL: string | null;
  uid: string;
};

type CloudflareResolvedPlayback = {
  playbackURL: string;
  iframePlaybackURL: string | null;
  lifecycleLive: boolean;
  videoUID: string | null;
};

type LiveStreamCommentWire = {
  id: string;
  sessionID: string;
  author: AppUser;
  body: string;
  createdAt: string;
};

type BroadcastKind = 'video' | 'radio';

type RadioNowPlayingWire = {
  id: string;
  title: string;
  trackNumber: number;
  explicit: boolean;
  releaseID: string;
  releaseTitle: string;
  artistName: string;
  artistHandle: string;
  artworkProvider: string | null;
  artworkBucket: string | null;
  artworkObjectKey: string | null;
};

Deno.serve((req) => withRequestLogging(req, async (log) => {
  if (req.method === 'OPTIONS') return optionsResponse();
  try {
    const url = new URL(req.url);
    const path = livePathTail(url.pathname);

    if (req.method === 'GET' && path.length === 2 && path[0] === 'radio' && path[1] === 'active') {
      setLogAuthUser(log, null);
      setLogAccountScope(log, 'public-radio');
      return await fetchActiveRadioSessions(log);
    }

    if (
      req.method === 'GET' &&
      path.length === 2 &&
      path[0] === 'session' &&
      !['viewer', 'comments', 'reports', 'manifest-debug'].includes(path[1])
    ) {
      setLogAuthUser(log, null);
      setLogAccountScope(log, 'public-live-session');
      return await fetchPublicSessionByID(path[1], log);
    }

    const authed = await currentUserId(req);
    setLogAuthUser(log, authed);
    if (!authed) return unauthorized();

    if (req.method === 'GET' && path.length === 2 && path[0] === 'radio' && path[1] === 'access') {
      return await fetchRadioAccess(url, authed, log);
    }
    if (req.method === 'GET' && path.length === 2 && path[0] === 'radio' && path[1] === 'session') {
      return await fetchActiveRadioSession(url, authed, log);
    }
    if (req.method === 'PATCH' && path.length === 3 && path[0] === 'radio' && path[1] === 'session' && path[2] === 'now-playing') {
      return await updateRadioNowPlaying(req, authed, log);
    }
    if (req.method === 'GET' && path.length === 2 && path[0] === 'radio' && path[1] === 'library') {
      return await fetchRadioLibraryStatus(url, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'radio' && path[1] === 'library') {
      return await saveRadioTrackToLibrary(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'radio' && path[1] === 'session') {
      return await createSession(req, authed, log, 'radio');
    }
    if (req.method === 'POST' && path.length === 3 && path[0] === 'radio' && path[1] === 'session' && path[2] === 'end') {
      return await endSession(req, authed, log, 'radio');
    }
    if (req.method === 'POST' && path.length === 3 && path[0] === 'radio' && path[1] === 'session' && path[2] === 'rotate-key') {
      return await rotateSessionKey(req, authed, log, 'radio');
    }

    if (req.method === 'GET' && path.length === 1 && path[0] === 'session') {
      return await fetchActiveSession(url, authed, log);
    }
    if (req.method === 'GET' && path.length === 2 && path[0] === 'session' && path[1] === 'viewer') {
      return await fetchViewerSession(url, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'verify-password') {
      return await verifyViewerPassword(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 1 && path[0] === 'session') {
      return await createSession(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'end') {
      return await endSession(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'rotate-key') {
      return await rotateSessionKey(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'heartbeat') {
      return await heartbeatSession(req, authed, log);
    }

    if (req.method === 'GET' && path.length === 2 && path[0] === 'session' && path[1] === 'comments') {
      return await fetchSessionComments(url, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'comments') {
      return await createSessionComment(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 3 && path[0] === 'session' && path[1] === 'tips' && path[2] === 'resolve') {
      return await resolvePendingTip(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'kick') {
      return await kickSessionViewer(req, authed, log);
    }
    if (req.method === 'POST' && path.length === 2 && path[0] === 'session' && path[1] === 'report') {
      return await reportLiveSession(req, authed, log);
    }
    if (req.method === 'GET' && path.length === 2 && path[0] === 'session' && path[1] === 'reports') {
      return await listLiveStreamReports(req, authed);
    }
    if (req.method === 'PATCH' && path.length === 3 && path[0] === 'session' && path[1] === 'reports' && path[2]) {
      return await reviewLiveStreamReport(req, authed, path[2]);
    }
    if (req.method === 'GET' && path.length === 2 && path[0] === 'session' && path[1] === 'manifest-debug') {
      return await debugManifest(url, authed, log);
    }
    return notFound();
  } catch (error) {
    return serverError(error);
  }
}));

function livePathTail(pathname: string): string[] {
  const parts = pathname.split('/').filter(Boolean);
  const idx = parts.lastIndexOf('live');
  if (idx < 0) return [];
  return parts.slice(idx + 1);
}

function normalizeLiveMode(input: unknown): 'mobile' | 'obs' {
  const value = String(input ?? '').trim().toLowerCase();
  if (value === 'obs') return 'obs';
  return 'mobile';
}

function normalizeBroadcastKind(input: unknown): BroadcastKind {
  return String(input ?? '').trim().toLowerCase() === 'radio' ? 'radio' : 'video';
}

function normalizeOptionalText(input: unknown, maxChars: number): string | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  return raw.slice(0, maxChars);
}

function normalizeUUID(input: unknown): string | null {
  const value = String(input ?? '').trim().toLowerCase();
  return UUID_PATTERN.test(value) ? value : null;
}

function relationRecord(value: unknown): Record<string, unknown> | null {
  const candidate = Array.isArray(value) ? value[0] : value;
  return candidate && typeof candidate === 'object' && !Array.isArray(candidate)
    ? candidate as Record<string, unknown>
    : null;
}

function normalizeIdempotencyKey(input: unknown): string | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  return raw.slice(0, IDEMPOTENCY_KEY_MAX_CHARS);
}

function normalizeViewerPassword(input: unknown): string | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  return raw;
}

function normalizedBase(value: string, fallback: string): string {
  const source = value.trim() || fallback;
  return source.replace(/\/+$/, '');
}

function sessionWire(
  row: Record<string, unknown>,
  resolvedPlayback?: CloudflareResolvedPlayback,
  nowPlaying?: RadioNowPlayingWire | null,
) {
  const rawTipGoal = row.tip_goal;
  const tipGoal = rawTipGoal != null && rawTipGoal !== '' ? Number(rawTipGoal) : null;
  const playbackURL = resolvedPlayback?.playbackURL ?? String(row.playback_url ?? '').trim();
  const viewerPasswordHash = String(row.viewer_password_hash ?? '').trim();
  return {
    id: String(row.id ?? ''),
    ownerUserID: String(row.owner_user_id ?? ''),
    mode: String(row.mode ?? 'mobile'),
    broadcastKind: normalizeBroadcastKind(row.broadcast_kind),
    nowPlaying: nowPlaying ?? null,
    nowPlayingUpdatedAt: row.now_playing_updated_at
      ? new Date(String(row.now_playing_updated_at)).toISOString()
      : null,
    title: normalizeOptionalText(row.title, TITLE_MAX_CHARS),
    description: normalizeOptionalText(row.description, DESCRIPTION_MAX_CHARS),
    streamKey: String(row.stream_key ?? ''),
    ingestURL: String(row.ingest_url ?? ''),
    playbackURL,
    iframePlaybackURL: resolvedPlayback?.iframePlaybackURL ?? parseCloudflareIframePlaybackURL(playbackURL),
    cloudflareUID: String(row.cloudflare_uid ?? ''),
    status: String(row.status ?? 'active'),
    tipGoal: (tipGoal != null && Number.isFinite(tipGoal) && tipGoal > 0) ? tipGoal : null,
    hasViewerPassword: viewerPasswordHash.length > 0,
    has_viewer_password: viewerPasswordHash.length > 0,
    startedAt: new Date(String(row.started_at ?? new Date().toISOString())).toISOString(),
    lastHeartbeatAt: row.last_heartbeat_at ? new Date(String(row.last_heartbeat_at)).toISOString() : null,
    endedAt: row.ended_at ? new Date(String(row.ended_at)).toISOString() : null,
    endedReason: row.ended_reason ? String(row.ended_reason) : null,
    createdAt: new Date(String(row.created_at ?? new Date().toISOString())).toISOString(),
    updatedAt: new Date(String(row.updated_at ?? new Date().toISOString())).toISOString(),
  };
}

function viewerSessionWire(
  row: Record<string, unknown>,
  resolvedPlayback?: CloudflareResolvedPlayback,
  nowPlaying?: RadioNowPlayingWire | null,
) {
  const base = sessionWire(row, resolvedPlayback, nowPlaying);
  return {
    ...base,
    streamKey: '',
    ingestURL: '',
    cloudflareUID: '',
  };
}

function bytesToBase64URL(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function base64URLToBytes(value: string): Uint8Array {
  const padded = value.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function deriveViewerPasswordHash(password: string, salt: Uint8Array): Promise<Uint8Array> {
  const material = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt,
      iterations: VIEWER_PASSWORD_PBKDF2_ITERATIONS,
    },
    material,
    256,
  );
  return new Uint8Array(bits);
}

async function hashViewerPassword(password: string): Promise<string> {
  const salt = new Uint8Array(16);
  crypto.getRandomValues(salt);
  const hash = await deriveViewerPasswordHash(password, salt);
  return [
    'pbkdf2_sha256',
    String(VIEWER_PASSWORD_PBKDF2_ITERATIONS),
    bytesToBase64URL(salt),
    bytesToBase64URL(hash),
  ].join('$');
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) {
    diff |= left[i] ^ right[i];
  }
  return diff === 0;
}

async function verifyViewerPasswordHash(password: string, storedHash: string): Promise<boolean> {
  const parts = storedHash.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2_sha256') return false;
  const iterations = Number.parseInt(parts[1], 10);
  if (iterations !== VIEWER_PASSWORD_PBKDF2_ITERATIONS) return false;
  const salt = base64URLToBytes(parts[2]);
  const expected = base64URLToBytes(parts[3]);
  const actual = await deriveViewerPasswordHash(password, salt);
  return constantTimeEqual(actual, expected);
}

function passwordAttemptKey(req: Request, ownerID: string): string {
  const forwarded = req.headers.get('cf-connecting-ip')
    ?? req.headers.get('x-forwarded-for')?.split(',')[0]
    ?? req.headers.get('x-real-ip')
    ?? 'unknown';
  return `${forwarded.trim().toLowerCase()}:${ownerID.trim().toLowerCase()}`;
}

function checkViewerPasswordRateLimit(req: Request, ownerID: string): boolean {
  const now = Date.now();
  const key = passwordAttemptKey(req, ownerID);
  const current = viewerPasswordAttempts.get(key);
  if (!current || current.resetAt <= now) {
    viewerPasswordAttempts.set(key, { count: 1, resetAt: now + VIEWER_PASSWORD_VERIFY_WINDOW_MS });
    return true;
  }
  if (current.count >= VIEWER_PASSWORD_VERIFY_LIMIT) {
    return false;
  }
  current.count += 1;
  return true;
}

function normalizeLiveCommentBody(input: unknown): string {
  const raw = String(input ?? '').trim();
  if (!raw) return '';
  return raw.slice(0, LIVE_COMMENT_MAX_CHARS);
}

function parseLiveCommentLimit(raw: string | null): number {
  const parsed = Number.parseInt(String(raw ?? '').trim(), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return 40;
  return Math.min(parsed, LIVE_COMMENT_FETCH_LIMIT_MAX);
}


function forbidden(message: string) {
  return json({ error: message }, 403);
}

async function isUserKickedFromSession(sessionID: string, userID: string): Promise<boolean> {
  const normalizedSessionID = String(sessionID).trim();
  const normalizedUserID = String(userID).trim().toLowerCase();
  if (!normalizedSessionID || !normalizedUserID) return false;

  const admin = serviceClient();
  const kick = await admin.from('live_stream_session_kicks')
    .select('id')
    .eq('session_id', normalizedSessionID)
    .eq('target_user_id', normalizedUserID)
    .limit(1)
    .maybeSingle();

  if (kick.error) {
    throw new Error(kick.error.message);
  }

  return Boolean(kick.data);
}

function liveCommentWire(row: Record<string, unknown>, usersByID: Map<string, AppUser>): LiveStreamCommentWire {
  const authorID = String(row.author_id ?? '').trim().toLowerCase();
  const author = usersByID.get(authorID) ?? {
    id: authorID,
    username: 'unknown',
    displayName: 'Unknown',
    bio: '',
    isVerified: false,
    isFounder: false,
    isPrivate: false,
    accountType: 'personal',
    avatarRef: null,
    avatarProvider: null,
    avatarBucket: null,
    avatarObjectKey: null,
    signatureRef: null,
    avatarVideoRef: null,
    websiteURL: null,
    venmoURL: null,
    cashAppURL: null,
    businessLocation: null,
    businessPhone: null,
    homeCity: null,
    subscriptionPlan: null,
    subscriptionExpiresAt: null,
    writeVersion: null,
  };

  return {
    id: String(row.id ?? ''),
    sessionID: String(row.session_id ?? ''),
    author,
    body: String(row.body ?? ''),
    createdAt: new Date(String(row.created_at ?? new Date().toISOString())).toISOString(),
  };
}

async function fetchSessionComments(url: URL, authed: string, log: RequestLogContext) {
  const sessionID = String(url.searchParams.get('session_id') ?? '').trim();
  if (!sessionID) return badRequest('session_id is required.');

  const admin = serviceClient();
  const session = await admin.from('live_stream_sessions')
    .select('id, owner_user_id')
    .eq('id', sessionID)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const ownerID = String((session.data as Record<string, unknown>).owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, [authed, ownerID]);

  const requesterID = authed.trim().toLowerCase();
  const blockedPeers = await mutuallyBlockedUserIDs(admin, [requesterID]);
  if (requesterID !== ownerID) {
    const kicked = await isUserKickedFromSession(sessionID, requesterID);
    if (kicked) return forbidden('You were removed from this live stream.');
    if (blockedPeers.has(ownerID)) return forbidden('You cannot view this live stream.');
  }

  const limit = parseLiveCommentLimit(url.searchParams.get('limit'));
  const commentsResp = await admin.from('live_stream_comments')
    .select('id, session_id, author_id, body, created_at')
    .eq('session_id', sessionID)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (commentsResp.error) return badRequest(commentsResp.error.message);

  const rows = (commentsResp.data ?? []) as Array<Record<string, unknown>>;
  const authorIDs = Array.from(new Set(rows.map((row) => String(row.author_id ?? '').trim().toLowerCase()).filter((id) => id.length > 0)));

  const usersByID = new Map<string, AppUser>();
  if (authorIDs.length > 0) {
    const usersResp = await admin.from('users')
      .select('*')
      .in('id', authorIDs);
    if (usersResp.error) return badRequest(usersResp.error.message);
    for (const row of (usersResp.data ?? []) as Array<Record<string, unknown>>) {
      const mapped = mapUser(row);
      usersByID.set(String(mapped.id).trim().toLowerCase(), mapped);
    }
  }

  const comments = rows
    .filter((row) => !blockedPeers.has(String(row.author_id ?? '').trim().toLowerCase()))
    .map((row) => liveCommentWire(row, usersByID))
    .reverse();
  return json({ comments });
}

async function createSessionComment(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json() as Record<string, unknown>;
  const sessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  if (!sessionID) return badRequest('session_id is required.');

  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID ?? payload.author_id ?? payload.authorID);
  if (!actorID) return unauthorized('Live comment scope denied');

  let body = normalizeLiveCommentBody(payload.body);
  if (!body) return badRequest('Comment body is required.');
  // Older app builds announce a tip with the legacy marker before the
  // off-platform payment is verified. Store those attempts as pending too,
  // so released clients cannot create an unconfirmed public tip banner.
  const legacyTipPrefix = '__scrolls_tip__:';
  if (body.startsWith(legacyTipPrefix)) {
    body = `__scrolls_tip_pending__:${body.slice(legacyTipPrefix.length)}`;
  }

  const admin = serviceClient();
  const session = await admin.from('live_stream_sessions')
    .select('id, owner_user_id, status')
    .eq('id', sessionID)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const sessionRow = session.data as Record<string, unknown>;
  const ownerID = String(sessionRow.owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, [actorID, ownerID]);

  if (actorID !== ownerID) {
    const kicked = await isUserKickedFromSession(sessionID, actorID);
    if (kicked) return forbidden('You were removed from this live stream.');
    if (await hasMutualBlock(admin, actorID, ownerID)) {
      return forbidden('You cannot comment on this live stream.');
    }
  }

  if (String(sessionRow.status ?? '').trim().toLowerCase() !== 'active') {
    return badRequest('Live stream is not active.');
  }

  const commentID = String(payload.id ?? '').trim() || crypto.randomUUID();

  const existing = await admin.from('live_stream_comments')
    .select('id, session_id, author_id, body, created_at')
    .eq('id', commentID)
    .maybeSingle();
  if (existing.error) return badRequest(existing.error.message);

  if (existing.data) {
    const row = existing.data as Record<string, unknown>;
    const existingAuthorID = String(row.author_id ?? '').trim().toLowerCase();
    const existingSessionID = String(row.session_id ?? '').trim();
    if (existingAuthorID !== actorID || existingSessionID !== sessionID) {
      return badRequest('Live comment ID conflict.');
    }

    const userResp = await admin.from('users').select('*').eq('id', actorID).maybeSingle();
    if (userResp.error || !userResp.data) return badRequest(userResp.error?.message ?? 'Could not load comment author.');
    const usersByID = new Map<string, AppUser>([[actorID, mapUser(userResp.data as Record<string, unknown>)]])
    return json({ comment: liveCommentWire(row, usersByID), idempotent: true });
  }

  const inserted = await admin.from('live_stream_comments')
    .insert({
      id: commentID,
      session_id: sessionID,
      author_id: actorID,
      body,
      created_at: new Date().toISOString(),
    })
    .select('id, session_id, author_id, body, created_at')
    .single();
  if (inserted.error || !inserted.data) {
    return badRequest(inserted.error?.message ?? 'Could not create live comment.');
  }

  const userResp = await admin.from('users').select('*').eq('id', actorID).maybeSingle();
  if (userResp.error || !userResp.data) return badRequest(userResp.error?.message ?? 'Could not load comment author.');

  const usersByID = new Map<string, AppUser>([[actorID, mapUser(userResp.data as Record<string, unknown>)]])
  return json({ comment: liveCommentWire(inserted.data as Record<string, unknown>, usersByID) });
}

async function resolvePendingTip(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json() as Record<string, unknown>;
  const sessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  const commentID = String(payload.comment_id ?? payload.commentID ?? '').trim();
  const accepted = Boolean(payload.accepted ?? false);
  if (!sessionID || !commentID) return badRequest('session_id and comment_id are required.');

  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Live tip scope denied');

  const admin = serviceClient();
  const session = await admin.from('live_stream_sessions')
    .select('id, owner_user_id')
    .eq('id', sessionID)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const ownerID = String((session.data as Record<string, unknown>).owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, [actorID, ownerID]);
  if (actorID !== ownerID) return forbidden('Only the live streamer can confirm tips.');

  const existing = await admin.from('live_stream_comments')
    .select('id, session_id, author_id, body, created_at')
    .eq('id', commentID)
    .eq('session_id', sessionID)
    .maybeSingle();
  if (existing.error) return badRequest(existing.error.message);
  if (!existing.data) return notFound();

  const row = existing.data as Record<string, unknown>;
  const pendingPrefix = '__scrolls_tip_pending__:';
  const confirmedPrefix = '__scrolls_tip_confirmed__:';
  const body = String(row.body ?? '');
  if (!body.startsWith(pendingPrefix)) {
    return badRequest('Tip is no longer pending.');
  }

  if (!accepted) {
    const removed = await admin.from('live_stream_comments')
      .delete()
      .eq('id', commentID)
      .eq('session_id', sessionID);
    if (removed.error) return badRequest(removed.error.message);
    return json({ ok: true, accepted: false, comment: null });
  }

  const confirmedBody = `${confirmedPrefix}${body.slice(pendingPrefix.length)}`;
  const updated = await admin.from('live_stream_comments')
    .update({ body: confirmedBody })
    .eq('id', commentID)
    .eq('session_id', sessionID)
    .select('id, session_id, author_id, body, created_at')
    .single();
  if (updated.error || !updated.data) {
    return badRequest(updated.error?.message ?? 'Could not confirm tip.');
  }

  const authorID = String((updated.data as Record<string, unknown>).author_id ?? '').trim().toLowerCase();
  const userResp = await admin.from('users').select('*').eq('id', authorID).maybeSingle();
  if (userResp.error || !userResp.data) {
    return badRequest(userResp.error?.message ?? 'Could not load tip author.');
  }
  const usersByID = new Map<string, AppUser>([[authorID, mapUser(userResp.data as Record<string, unknown>)]]);
  return json({
    ok: true,
    accepted: true,
    comment: liveCommentWire(updated.data as Record<string, unknown>, usersByID),
  });
}

async function reportLiveSession(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json() as Record<string, unknown>;
  const sessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  const ownerUserID = String(payload.owner_user_id ?? payload.ownerUserID ?? '').trim().toLowerCase();
  const reason = normalizeReportReason(payload.reason);
  const notes = normalizeReportNotes(payload.notes);
  if (!sessionID && !ownerUserID) return badRequest('session_id or owner_user_id is required.');
  if (!isValidSafetyReportReason(reason)) return badRequest('Invalid report reason.');

  const admin = serviceClient();
  let lookup = admin.from('live_stream_sessions')
    .select('id, owner_user_id, status, title, created_at');
  lookup = sessionID ? lookup.eq('id', sessionID) : lookup.eq('owner_user_id', ownerUserID).eq('status', 'active');
  const session = await lookup.order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const row = session.data as Record<string, unknown>;
  const resolvedSessionID = String(row.id ?? '').trim();
  const ownerID = String(row.owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, [authed, ownerID, resolvedSessionID]);
  if (ownerID === authed.trim().toLowerCase()) return badRequest('Cannot report your own live stream.');

  const write = await admin.from('live_stream_reports').upsert({
    session_id: resolvedSessionID,
    owner_user_id: ownerID,
    reporter_id: authed.trim().toLowerCase(),
    reason,
    notes,
    status: 'pending',
    reviewed_by: null,
    reviewed_at: null,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'session_id,reporter_id' });
  if (write.error) return badRequest(write.error.message);

  // Auto-stop threshold: 5 or more distinct reporters within the last
  // 10 minutes ends the broadcast.  Apple's UGC live-streaming guidance
  // expects an automated moderation trigger — the threshold is
  // intentionally conservative so coordinated brigading doesn't
  // accidentally kill an active stream.  Best-effort: a failure here
  // shouldn't surface to the reporter.
  try {
    const windowStartISO = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const recent = await admin.from('live_stream_reports')
      .select('reporter_id')
      .eq('session_id', resolvedSessionID)
      .gte('created_at', windowStartISO);
    if (!recent.error && Array.isArray(recent.data)) {
      const distinctReporters = new Set(
        recent.data.map((row) => String((row as { reporter_id?: unknown }).reporter_id ?? '').trim().toLowerCase()).filter(Boolean)
      );
      const AUTO_STOP_REPORT_THRESHOLD = 5;
      if (distinctReporters.size >= AUTO_STOP_REPORT_THRESHOLD) {
        const endedAtISO = new Date().toISOString();
        // Mark the broadcast ended — the broadcaster's iOS client polls
        // this status and will tear down the publish pipeline as soon
        // as it sees the flip.
        await admin.from('live_stream_sessions')
          .update({
            status:     'ended',
            ended_at:   endedAtISO,
            updated_at: endedAtISO,
          })
          .eq('id', resolvedSessionID)
          .eq('status', 'active');
        // Mark the contributing reports as confirmed so the moderation
        // queue shows the resolution and we don't ask reviewers to
        // re-decide what the auto-trigger already handled.
        await admin.from('live_stream_reports')
          .update({
            status:      'confirmed',
            reviewed_at: endedAtISO,
            updated_at:  endedAtISO,
          })
          .eq('session_id', resolvedSessionID)
          .eq('status', 'pending');
        console.warn(JSON.stringify({
          event:               'live_stream_auto_terminated',
          session_id:          resolvedSessionID,
          owner_user_id:       ownerID,
          distinct_reporters:  distinctReporters.size,
          window_minutes:      10,
          threshold:           AUTO_STOP_REPORT_THRESHOLD,
        }));
      }
    }
  } catch (autoStopError) {
    console.error(JSON.stringify({
      event:       'live_stream_auto_stop_check_error',
      session_id:  resolvedSessionID,
      error:       autoStopError instanceof Error ? autoStopError.message : String(autoStopError),
    }));
  }

  return json({ ok: true });
}

// ── Founder/admin: live-stream report review queue ──────────────────────────

async function isLiveReportReviewer(
  admin: ReturnType<typeof serviceClient>,
  userID: string,
): Promise<boolean> {
  const row = await admin.from('users').select('is_founder, is_admin').eq('id', userID.toLowerCase()).maybeSingle();
  if (row.error || !row.data) return false;
  return Boolean(row.data.is_founder ?? false) || Boolean(row.data.is_admin ?? false);
}

async function listLiveStreamReports(req: Request, authed: string): Promise<Response> {
  const admin = serviceClient();
  if (!(await isLiveReportReviewer(admin, authed))) return unauthorized();

  const url = new URL(req.url);
  const status = String(url.searchParams.get('status') ?? 'pending').trim().toLowerCase();
  const limit = Math.max(1, Math.min(200, Number(url.searchParams.get('limit') ?? '100')));

  let query = admin.from('live_stream_reports')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (['pending', 'confirmed', 'dismissed'].includes(status)) {
    query = query.eq('status', status);
  }
  const reports = await query;
  if (reports.error) return badRequest(reports.error.message);
  const rows = reports.data ?? [];

  const ownerIDs = Array.from(new Set(rows.map((row) => String(row.owner_user_id))));
  const reporterIDs = Array.from(new Set(rows.map((row) => String(row.reporter_id))));
  const sessionIDs = Array.from(new Set(rows.map((row) => String(row.session_id ?? '')).filter(Boolean)));

  const [owners, reporters, sessions] = await Promise.all([
    ownerIDs.length ? fetchUsersByIds(ownerIDs) : Promise.resolve({}),
    reporterIDs.length ? fetchUsersByIds(reporterIDs) : Promise.resolve({}),
    sessionIDs.length
      ? admin.from('live_stream_sessions').select('id, title, status, created_at, ended_at').in('id', sessionIDs)
      : Promise.resolve({ data: [] as Record<string, unknown>[], error: null }),
  ]);
  const sessionMap: Record<string, Record<string, unknown>> = {};
  for (const row of (sessions.data ?? [])) {
    sessionMap[String(row.id)] = row as Record<string, unknown>;
  }

  const payload = rows.map((row) => {
    const oid = String(row.owner_user_id);
    const rid = String(row.reporter_id);
    const sid = row.session_id ? String(row.session_id) : null;
    const sessionRow = sid ? sessionMap[sid] : undefined;
    return {
      id:           String(row.id),
      sessionID:    sid,
      ownerUserID:  oid,
      owner:        (owners as Record<string, unknown>)[oid] ?? null,
      reporterID:   rid,
      reporter:     (reporters as Record<string, unknown>)[rid] ?? null,
      reason:       String(row.reason ?? ''),
      notes:        row.notes ? String(row.notes) : null,
      status:       String(row.status ?? 'pending'),
      reviewedAt:   row.reviewed_at ? new Date(String(row.reviewed_at)).toISOString() : null,
      createdAt:    new Date(String(row.created_at)).toISOString(),
      session:      sessionRow ? {
        id:        String(sessionRow.id ?? ''),
        title:     sessionRow.title ? String(sessionRow.title) : null,
        status:    String(sessionRow.status ?? ''),
        createdAt: sessionRow.created_at ? new Date(String(sessionRow.created_at)).toISOString() : null,
        endedAt:   sessionRow.ended_at ? new Date(String(sessionRow.ended_at)).toISOString() : null,
      } : null,
    };
  });
  return json(payload);
}

async function reviewLiveStreamReport(req: Request, authed: string, reportID: string): Promise<Response> {
  if (!reportID) return badRequest('reportID required.');
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const status = String(payload.status ?? '').trim().toLowerCase();
  if (!['confirmed', 'dismissed'].includes(status)) return badRequest('Invalid status.');
  const admin = serviceClient();
  if (!(await isLiveReportReviewer(admin, authed))) return unauthorized();
  const write = await admin.from('live_stream_reports').update({
    status,
    reviewed_by: authed.toLowerCase(),
    reviewed_at: new Date().toISOString(),
    updated_at:  new Date().toISOString(),
  }).eq('id', reportID);
  if (write.error) return badRequest(write.error.message);
  return json({ ok: true });
}

async function kickSessionViewer(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json() as Record<string, unknown>;
  const sessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  if (!sessionID) return badRequest('session_id is required.');

  // target_user_id is the viewer being removed — any user, not restricted to the actor's account scope.
  const targetUserID = String(
    payload.target_user_id ?? payload.targetUserID ?? payload.viewer_user_id ?? payload.viewerUserID ?? ''
  ).trim().toLowerCase();
  if (!targetUserID) return badRequest('target_user_id is required.');

  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID ?? payload.owner_user_id ?? payload.ownerUserID);
  if (!actorID) return unauthorized('Live stream scope denied');

  const reason = normalizeOptionalText(payload.reason, LIVE_COMMENT_MAX_CHARS);
  const admin = serviceClient();

  const session = await admin.from('live_stream_sessions')
    .select('id, owner_user_id, status')
    .eq('id', sessionID)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const sessionRow = session.data as Record<string, unknown>;
  const ownerID = String(sessionRow.owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, [actorID, ownerID, targetUserID]);

  if (actorID !== ownerID) {
    return unauthorized('Only the live streamer can moderate viewers.');
  }

  if (String(sessionRow.status ?? '').trim().toLowerCase() !== 'active') {
    return badRequest('Live stream is not active.');
  }

  if (targetUserID === ownerID) {
    return badRequest('You cannot remove the live streamer.');
  }

  const nowISO = new Date().toISOString();
  const kicked = await admin.from('live_stream_session_kicks')
    .upsert({
      session_id: sessionID,
      target_user_id: targetUserID,
      kicked_by_user_id: ownerID,
      reason,
      created_at: nowISO,
    }, {
      onConflict: 'session_id,target_user_id',
    });
  if (kicked.error) return badRequest(kicked.error.message);

  const removedComments = await admin.from('live_stream_comments')
    .delete()
    .eq('session_id', sessionID)
    .eq('author_id', targetUserID);
  if (removedComments.error) return badRequest(removedComments.error.message);

  return json({ ok: true, sessionID, targetUserID });
}

async function resolvedActorID(authed: string, requestedRaw: unknown): Promise<string | null> {
  const requested = String(requestedRaw ?? '').trim();
  return await resolveScopedAccountID(authed, requested);
}

function isGoldSubscriptionPlan(plan: unknown): boolean {
  const normalized = String(plan ?? '').trim().toLowerCase();
  return GOLD_SUBSCRIPTION_IDS.has(normalized) || normalized.startsWith('scrolls.gold');
}

function hasActiveSubscriptionExpiry(expiresRaw: unknown): boolean {
  if (!expiresRaw) return true;
  const expires = new Date(String(expiresRaw));
  return Number.isFinite(expires.valueOf()) && expires > new Date();
}

function mobileHeartbeatCutoffISO(): string {
  return new Date(Date.now() - MOBILE_HEARTBEAT_STALE_MS).toISOString();
}

async function endStaleMobileSessions(
  admin: ReturnType<typeof serviceClient>,
  ownerIDs: string[] | null = null,
): Promise<void> {
  const cutoffISO = mobileHeartbeatCutoffISO();
  const nowISO = new Date().toISOString();
  const normalizedOwnerIDs = ownerIDs?.map((id) => id.trim().toLowerCase()).filter(Boolean) ?? [];

  let staleLookup = admin.from("live_stream_sessions")
    .select("id, cloudflare_uid")
    .eq("status", "active")
    .eq("mode", "mobile")
    .lt("last_heartbeat_at", cutoffISO);
  if (normalizedOwnerIDs.length > 0) {
    staleLookup = staleLookup.in("owner_user_id", normalizedOwnerIDs);
  }

  const stale = await staleLookup;
  if (stale.error) {
    console.warn("Failed to find stale mobile live sessions: " + stale.error.message);
    return;
  }

  const rows = (stale.data ?? []) as Array<Record<string, unknown>>;
  const staleIDs = rows.map((row) => String(row.id ?? "").trim()).filter(Boolean);
  if (staleIDs.length === 0) return;

  const ended = await admin.from("live_stream_sessions")
    .update({
      status: "ended",
      ended_at: nowISO,
      ended_reason: "heartbeat_timeout",
      updated_at: nowISO,
    })
    .in("id", staleIDs)
    .eq("status", "active");

  if (ended.error) {
    console.warn("Failed to end stale mobile live sessions: " + ended.error.message);
    return;
  }

  for (const row of rows) {
    try {
      await deleteCloudflareLiveInput(row.cloudflare_uid);
    } catch (cleanupError) {
      const cleanupMessage = cleanupError instanceof Error ? cleanupError.message : String(cleanupError);
      console.warn("Stale mobile live Cloudflare cleanup failed: " + cleanupMessage);
    }
  }
}

function parseCloudflarePlaybackURL(result: Record<string, unknown>, uid: string): string | null {
  // Use the Live Input UID playback URL so viewers always follow the active broadcast
  // for this channel (instead of pinning to a per-broadcast video URL).
  if (uid && CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN) {
    return `${normalizedBase(CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN, 'https://customer-placeholder.cloudflarestream.com')}/${uid}/manifest/video.m3u8`;
  }

  const playback = result.playback as Record<string, unknown> | undefined;
  const hls = String(playback?.hls ?? '').trim();
  if (hls) return hls;
  const dash = String(playback?.dash ?? '').trim();
  if (dash) return dash;
  return null;
}


function parseCloudflareIframePlaybackURL(playbackURLRaw: string): string | null {
  const playbackURL = String(playbackURLRaw ?? '').trim();
  if (!playbackURL) return null;
  let parsed: URL;
  try {
    parsed = new URL(playbackURL);
  } catch {
    return null;
  }

  const identifier = parsed.pathname.split('/').filter(Boolean)[0] ?? '';
  if (!identifier) return null;

  const iframe = new URL(`${parsed.protocol}//${parsed.host}/${identifier}/iframe`);
  iframe.searchParams.set('autoplay', 'true');
  iframe.searchParams.set('muted', 'true');
  iframe.searchParams.set('playsinline', 'true');
  iframe.searchParams.set('preload', 'auto');
  iframe.searchParams.set('controls', 'true');
  return iframe.toString();
}

type CloudflareLifecyclePayload = {
  live: boolean;
  videoUID: string | null;
};

function parseLifecycleURL(playbackURLRaw: string, fallbackUIDRaw: unknown): URL | null {
  const playbackURL = String(playbackURLRaw ?? '').trim();
  if (playbackURL) {
    try {
      const parsed = new URL(playbackURL);
      const identifier = parsed.pathname.split('/').filter(Boolean)[0] ?? '';
      if (identifier) {
        return new URL(`${parsed.protocol}//${parsed.host}/${identifier}/lifecycle`);
      }
    } catch {
      // Fall through to customer-subdomain + input-UID fallback.
    }
  }

  const fallbackUID = String(fallbackUIDRaw ?? '').trim();
  if (!fallbackUID || !CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN) return null;
  try {
    const base = normalizedBase(
      CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN,
      'https://customer-placeholder.cloudflarestream.com',
    );
    return new URL(`${base}/${fallbackUID}/lifecycle`);
  } catch {
    return null;
  }
}

async function fetchCloudflareLifecyclePlayback(
  playbackURLRaw: string,
  fallbackUIDRaw: unknown,
): Promise<CloudflareLifecyclePayload | null> {
  const lifecycleURL = parseLifecycleURL(playbackURLRaw, fallbackUIDRaw);
  if (!lifecycleURL) return null;

  try {
    const resp = await fetch(lifecycleURL, {
      method: 'GET',
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    });
    if (!resp.ok) return null;
    const payload = await resp.json() as Record<string, unknown>;
    const videoUID = String(payload.videoUID ?? '').trim();
    const live = Boolean(payload.live ?? false) || videoUID.length > 0;
    return {
      live,
      videoUID: videoUID.length > 0 ? videoUID : null,
    };
  } catch {
    return null;
  }
}

function playbackURLForVideoUID(
  playbackURLRaw: string,
  fallbackUIDRaw: unknown,
  videoUIDRaw: unknown,
): string | null {
  const videoUID = String(videoUIDRaw ?? '').trim();
  if (!videoUID) return null;

  const playbackURL = String(playbackURLRaw ?? '').trim();
  if (playbackURL) {
    try {
      const parsed = new URL(playbackURL);
      return `${parsed.protocol}//${parsed.host}/${videoUID}/manifest/video.m3u8`;
    } catch {
      // Fall through to the configured customer subdomain.
    }
  }

  if (!CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN) return null;
  const base = normalizedBase(
    CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN,
    'https://customer-placeholder.cloudflarestream.com',
  );
  return `${base}/${videoUID}/manifest/video.m3u8`;
}

async function resolveViewerPlaybackForRow(
  row: Record<string, unknown>,
  options: { hideUntilReady: boolean },
): Promise<CloudflareResolvedPlayback> {
  const rawPlaybackURL = String(row.playback_url ?? '').trim();
  const cloudflareUID = String(row.cloudflare_uid ?? '').trim();
  const lifecycle = await fetchCloudflareLifecyclePlayback(rawPlaybackURL, cloudflareUID);

  if (lifecycle?.videoUID) {
    const resolvedPlaybackURL = playbackURLForVideoUID(rawPlaybackURL, cloudflareUID, lifecycle.videoUID)
      ?? rawPlaybackURL;
    return {
      playbackURL: resolvedPlaybackURL,
      iframePlaybackURL: parseCloudflareIframePlaybackURL(resolvedPlaybackURL),
      lifecycleLive: lifecycle.live,
      videoUID: lifecycle.videoUID,
    };
  }

  if (options.hideUntilReady) {
    return {
      playbackURL: '',
      iframePlaybackURL: null,
      lifecycleLive: Boolean(lifecycle?.live ?? false),
      videoUID: lifecycle?.videoUID ?? null,
    };
  }

  return {
    playbackURL: rawPlaybackURL,
    iframePlaybackURL: parseCloudflareIframePlaybackURL(rawPlaybackURL),
    lifecycleLive: Boolean(lifecycle?.live ?? false),
    videoUID: lifecycle?.videoUID ?? null,
  };
}

function parseCloudflareIngest(result: Record<string, unknown>): { streamKey: string; ingestURL: string } | null {
  const candidateRoots: Array<Record<string, unknown> | undefined> = [
    result.rtmps as Record<string, unknown> | undefined,
    result.rtmp as Record<string, unknown> | undefined,
  ];

  for (const candidate of candidateRoots) {
    if (!candidate) continue;
    const baseURL = String(candidate.url ?? '').trim();
    const streamKey = String(candidate.streamKey ?? '').trim();
    if (!baseURL) continue;
    if (!streamKey) continue;
    return {
      streamKey,
      ingestURL: `${baseURL}${streamKey}`,
    };
  }

  return null;
}


function cloudflareAuthHint(status: number, cfDetail: string): string {
  if (status === 401 && cfDetail.includes('10000')) {
    return ' — verify CLOUDFLARE_ACCOUNT_ID matches the token account and token has Stream:Edit permission';
  }
  return '';
}

function cloudflareUnavailable(message: string) {
  return json({ error: message }, 503);
}

function parseCloudflareAPIError(payload: Record<string, unknown>): string {
  const errors = Array.isArray(payload.errors) ? payload.errors : [];
  const messages = Array.isArray(payload.messages) ? payload.messages : [];

  const parts: string[] = [];

  for (const item of errors) {
    const record = item as Record<string, unknown>;
    const code = String(record.code ?? "").trim();
    const message = String(record.message ?? "").trim();
    if (code && message) {
      parts.push(`${code}: ${message}`);
    } else if (message) {
      parts.push(message);
    }
  }

  for (const item of messages) {
    const record = item as Record<string, unknown>;
    const message = String(record.message ?? "").trim();
    if (message) {
      parts.push(message);
    }
  }

  return parts.join(" | ");
}

async function createCloudflareLiveInput(title: string | null, description: string | null): Promise<CloudflareLiveInput> {
  if (!CLOUDFLARE_ACCOUNT_ID || !CLOUDFLARE_API_TOKEN) {
    throw new Error("Cloudflare live is not configured (missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_API_TOKEN).");
  }

  const requestBody: Record<string, unknown> = {
    meta: {
      name: title ?? "Scrolls Live",
      ...(description ? { description } : {}),
    },
    recording: {
      mode: "automatic",
    },
  };

  const resp = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    },
  );

  let payload: Record<string, unknown> = {};
  try {
    payload = await resp.json() as Record<string, unknown>;
  } catch {
    payload = {};
  }

  if (!resp.ok) {
    const cfDetail = parseCloudflareAPIError(payload);
    const suffix = cfDetail ? ` (${cfDetail})` : "";
    const hint = cloudflareAuthHint(resp.status, cfDetail);
    throw new Error(`Cloudflare live input API failed with status ${resp.status}${suffix}${hint}`);
  }

  const success = Boolean(payload.success ?? true);
  if (!success) {
    const cfDetail = parseCloudflareAPIError(payload);
    const suffix = cfDetail ? ` (${cfDetail})` : "";
    throw new Error(`Cloudflare live input API returned success=false${suffix}`);
  }

  const result = (payload.result ?? {}) as Record<string, unknown>;
  const uid = String(result.uid ?? "").trim();
  const ingest = parseCloudflareIngest(result);

  if (!uid) {
    throw new Error("Cloudflare live input response missing uid.");
  }
  if (!ingest) {
    throw new Error("Cloudflare live input response missing ingest url/stream key.");
  }

  const playbackURL = parseCloudflarePlaybackURL(result, uid);
  if (!playbackURL) {
    throw new Error("Cloudflare playback URL unavailable (set CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN).");
  }

  return {
    uid,
    streamKey: ingest.streamKey,
    ingestURL: ingest.ingestURL,
    playbackURL,
  };
}

async function deleteCloudflareLiveInput(uidRaw: unknown): Promise<void> {
  const uid = String(uidRaw ?? '').trim();
  if (!uid) return;

  if (!CLOUDFLARE_ACCOUNT_ID || !CLOUDFLARE_API_TOKEN) {
    throw new Error('Cloudflare live is not configured (missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_API_TOKEN).');
  }

  const resp = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs/${uid}`,
    {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
      },
    },
  );

  let payload: Record<string, unknown> = {};
  try {
    payload = await resp.json() as Record<string, unknown>;
  } catch {
    payload = {};
  }

  if (!resp.ok) {
    // Already deleted/missing should not block workflow.
    if (resp.status === 404) return;
    const cfDetail = parseCloudflareAPIError(payload);
    const suffix = cfDetail ? ` (${cfDetail})` : '';
    const hint = cloudflareAuthHint(resp.status, cfDetail);
    throw new Error(`Cloudflare live input delete failed with status ${resp.status}${suffix}${hint}`);
  }

  const success = Boolean(payload.success ?? true);
  if (!success) {
    const cfDetail = parseCloudflareAPIError(payload);
    const suffix = cfDetail ? ` (${cfDetail})` : '';
    throw new Error(`Cloudflare live input delete returned success=false${suffix}`);
  }
}
async function actorHasLiveStreamAccess(actorID: string, authed: string): Promise<boolean> {
  if (isFounderUserID(actorID) || isFounderUserID(authed)) return true;
  const admin = serviceClient();
  const userRow = await admin.from('users')
    .select('subscription_plan, subscription_expires_at, is_founder')
    .eq('id', actorID)
    .maybeSingle();
  if (userRow.error || !userRow.data) return false;
  const row = userRow.data as Record<string, unknown>;
  if (Boolean(row.is_founder ?? false)) return true;
  return isGoldSubscriptionPlan(row.subscription_plan) && hasActiveSubscriptionExpiry(row.subscription_expires_at);
}

function actorHasRadioAccess(actorID: string, authed: string): boolean {
  return RADIO_BROADCASTER_IDS.has(actorID)
    || RADIO_BROADCASTER_IDS.has(authed);
}

async function fetchRadioNowPlayingTracks(
  trackIDs: string[],
): Promise<Map<string, RadioNowPlayingWire>> {
  const normalized = Array.from(new Set(trackIDs.map(normalizeUUID).filter((id): id is string => Boolean(id))));
  const resolved = new Map<string, RadioNowPlayingWire>();
  if (!normalized.length) return resolved;

  const tracks = await serviceClient().from('music_tracks')
    .select(
      'id,title,track_number,explicit,release_id,'
      + 'music_releases!inner(id,title,status,published_at,cover_provider,cover_bucket,cover_object_key,'
      + 'music_artists!inner(handle,display_name))',
    )
    .in('id', normalized)
    .eq('music_releases.status', 'published')
    .lte('music_releases.published_at', new Date().toISOString());
  if (tracks.error) throw tracks.error;

  for (const raw of (tracks.data ?? []) as Array<Record<string, unknown>>) {
    const trackID = normalizeUUID(raw.id);
    const release = relationRecord(raw.music_releases);
    const artist = relationRecord(release?.music_artists);
    const releaseID = normalizeUUID(release?.id ?? raw.release_id);
    if (!trackID || !release || !artist || !releaseID) continue;
    resolved.set(trackID, {
      id: trackID,
      title: String(raw.title ?? '').trim() || 'Untitled song',
      trackNumber: Math.max(1, Number(raw.track_number ?? 1) || 1),
      explicit: Boolean(raw.explicit ?? false),
      releaseID,
      releaseTitle: String(release.title ?? '').trim() || 'Untitled release',
      artistName: String(artist.display_name ?? '').trim() || 'Unknown artist',
      artistHandle: String(artist.handle ?? '').trim(),
      artworkProvider: normalizeOptionalText(release.cover_provider, 40),
      artworkBucket: normalizeOptionalText(release.cover_bucket, 160),
      artworkObjectKey: normalizeOptionalText(release.cover_object_key, 512),
    });
  }
  return resolved;
}

async function radioNowPlayingForRow(row: Record<string, unknown>): Promise<RadioNowPlayingWire | null> {
  const trackID = normalizeUUID(row.now_playing_track_id);
  if (!trackID) return null;
  return (await fetchRadioNowPlayingTracks([trackID])).get(trackID) ?? null;
}

async function fetchRadioAccess(url: URL, authed: string, log: RequestLogContext) {
  const actorID = await resolvedActorID(authed, url.searchParams.get('user_id'));
  if (!actorID) return unauthorized('Radio account scope denied.');
  setLogAccountScope(log, actorID);
  return json({ allowed: actorHasRadioAccess(actorID, authed) });
}

async function fetchActiveRadioSession(url: URL, authed: string, log: RequestLogContext) {
  const actorID = await resolvedActorID(authed, url.searchParams.get('user_id'));
  if (!actorID) return unauthorized('Radio account scope denied.');
  setLogAccountScope(log, actorID);
  if (!actorHasRadioAccess(actorID, authed)) return forbidden('This account does not have Apollo Radio access.');

  const session = await serviceClient().from('live_stream_sessions')
    .select('*')
    .eq('owner_user_id', actorID)
    .eq('broadcast_kind', 'radio')
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return json({ session: null });
  const row = session.data as Record<string, unknown>;
  const nowPlaying = await radioNowPlayingForRow(row);
  return json({ session: sessionWire(row, undefined, nowPlaying) });
}

async function fetchActiveRadioSessions(log: RequestLogContext) {
  const admin = serviceClient();
  const sessions = await admin.from('live_stream_sessions')
    .select('*')
    .eq('broadcast_kind', 'radio')
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(20);
  if (sessions.error) return badRequest(sessions.error.message);

  const rows = (sessions.data ?? []) as Array<Record<string, unknown>>;
  const ownerIDs = Array.from(new Set(rows.map((row) => String(row.owner_user_id ?? '')).filter(Boolean)));
  const trackIDs = rows.map((row) => String(row.now_playing_track_id ?? '')).filter(Boolean);
  setLogAccountScope(log, ownerIDs.length ? ownerIDs : 'public-radio');
  const users = await fetchUsersByIds(ownerIDs);
  const nowPlaying = await fetchRadioNowPlayingTracks(trackIDs);
  const resolved = await Promise.all(rows.map(async (row) => {
    const ownerID = String(row.owner_user_id ?? '');
    const ownerUser = users[ownerID];
    if (!ownerUser || ownerUser.isPrivate) return null;
    const playback = await resolveViewerPlaybackForRow(row, { hideUntilReady: true });
    return {
      ...viewerSessionWire(
        row,
        playback,
        nowPlaying.get(String(row.now_playing_track_id ?? '').trim().toLowerCase()) ?? null,
      ),
      ownerUser,
      owner_user: ownerUser,
    };
  }));
  return json({ sessions: resolved.filter(Boolean) });
}

async function updateRadioNowPlaying(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Radio account scope denied.');
  setLogAccountScope(log, actorID);
  if (!actorHasRadioAccess(actorID, authed)) return forbidden('This account does not have Apollo Radio access.');

  const sessionID = normalizeUUID(payload.session_id ?? payload.sessionID);
  if (!sessionID) return badRequest('A valid radio session is required.');

  const rawTrackID = String(payload.track_id ?? payload.trackID ?? '').trim();
  const trackID = rawTrackID ? normalizeUUID(rawTrackID) : null;
  if (rawTrackID && !trackID) return badRequest('A valid Apollo catalog track is required.');

  const admin = serviceClient();
  const active = await admin.from('live_stream_sessions')
    .select('*')
    .eq('id', sessionID)
    .eq('owner_user_id', actorID)
    .eq('broadcast_kind', 'radio')
    .eq('status', 'active')
    .maybeSingle();
  if (active.error) return badRequest(active.error.message);
  if (!active.data) return notFound();

  let selectedTrack: RadioNowPlayingWire | null = null;
  if (trackID) {
    selectedTrack = (await fetchRadioNowPlayingTracks([trackID])).get(trackID) ?? null;
    if (!selectedTrack) return badRequest('Choose a published song from the Apollo catalog.');
  }

  const nowISO = new Date().toISOString();
  const updated = await admin.from('live_stream_sessions')
    .update({
      now_playing_track_id: trackID,
      now_playing_updated_at: trackID ? nowISO : null,
      updated_at: nowISO,
    })
    .eq('id', sessionID)
    .eq('owner_user_id', actorID)
    .eq('status', 'active')
    .select('*')
    .single();
  if (updated.error || !updated.data) {
    return badRequest(updated.error?.message ?? 'Could not update the current radio song.');
  }
  return json({ session: sessionWire(updated.data as Record<string, unknown>, undefined, selectedTrack) });
}

async function fetchRadioLibraryStatus(url: URL, authed: string, log: RequestLogContext) {
  const actorID = await resolvedActorID(authed, url.searchParams.get('user_id'));
  if (!actorID) return unauthorized('Library account scope denied.');
  setLogAccountScope(log, actorID);
  const trackID = normalizeUUID(url.searchParams.get('track_id'));
  if (!trackID) return badRequest('A valid Apollo catalog track is required.');

  const saved = await serviceClient().from('music_library_items')
    .select('id')
    .eq('user_id', actorID)
    .eq('track_id', trackID)
    .limit(1)
    .maybeSingle();
  if (saved.error) return badRequest(saved.error.message);
  return json({ saved: Boolean(saved.data) });
}

async function saveRadioTrackToLibrary(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Library account scope denied.');
  setLogAccountScope(log, actorID);
  const trackID = normalizeUUID(payload.track_id ?? payload.trackID);
  if (!trackID) return badRequest('A valid Apollo catalog track is required.');

  const track = (await fetchRadioNowPlayingTracks([trackID])).get(trackID);
  if (!track) return badRequest('Only published Apollo catalog songs can be saved.');

  const admin = serviceClient();
  const existing = await admin.from('music_library_items')
    .select('id')
    .eq('user_id', actorID)
    .eq('track_id', trackID)
    .limit(1)
    .maybeSingle();
  if (existing.error) return badRequest(existing.error.message);
  if (existing.data) return json({ saved: true, idempotent: true });

  const inserted = await admin.from('music_library_items')
    .insert({ user_id: actorID, track_id: trackID })
    .select('id')
    .single();
  if (inserted.error) {
    if (inserted.error.code === '23505') return json({ saved: true, idempotent: true });
    return badRequest(inserted.error.message);
  }
  return json({ saved: true, idempotent: false }, 201);
}

async function fetchActiveSession(url: URL, authed: string, log: RequestLogContext) {
  const actorID = await resolvedActorID(authed, url.searchParams.get('user_id'));
  if (!actorID) return unauthorized('Live stream scope denied');
  setLogAccountScope(log, actorID);

  const admin = serviceClient();
  await endStaleMobileSessions(admin, [actorID]);
  // Apollo Radio broadcasts are audio for Apollo, not Scrolls live video. They
  // share this table, so the Scrolls-facing lookups have to exclude them or
  // going on air in Apollo makes the artist appear live on Scrolls too.
  const session = await admin.from('live_stream_sessions')
    .select('*')
    .eq('owner_user_id', actorID)
    .eq('status', 'active')
    .neq('broadcast_kind', 'radio')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);

  if (!session.data) {
    return json({ session: null });
  }
  const row = session.data as Record<string, unknown>;
  const resolvedPlayback = await resolveViewerPlaybackForRow(row, { hideUntilReady: false });
  return json({ session: sessionWire(row, resolvedPlayback) });
}

async function fetchPublicSessionByID(sessionIDRaw: string, log: RequestLogContext) {
  const sessionID = String(sessionIDRaw ?? '').trim();
  if (!sessionID) return badRequest('session id is required');

  const admin = serviceClient();
  const session = await admin.from('live_stream_sessions')
    .select('*')
    .eq('id', sessionID)
    .neq('broadcast_kind', 'radio')
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return notFound();

  const row = session.data as Record<string, unknown>;
  const ownerID = String(row.owner_user_id ?? '').trim().toLowerCase();
  setLogAccountScope(log, ownerID || 'public-live-session');
  if (!ownerID) return notFound();

  const users = await fetchUsersByIds([ownerID]);
  const ownerUser = users[ownerID];
  if (!ownerUser || ownerUser.isPrivate) {
    return json({ session: null, unavailable: true, reason: 'private' }, 404);
  }

  const hasViewerPassword = String(row.viewer_password_hash ?? '').trim().length > 0;
  if (hasViewerPassword) {
    return json({ session: null, unavailable: true, reason: 'password_required' }, 404);
  }

  if (String(row.status ?? '').trim().toLowerCase() === 'active') {
    await endStaleMobileSessions(admin, [ownerID]);
  }

  const refreshed = await admin.from('live_stream_sessions')
    .select('*')
    .eq('id', sessionID)
    .maybeSingle();
  if (refreshed.error) return badRequest(refreshed.error.message);
  if (!refreshed.data) return notFound();

  const latest = refreshed.data as Record<string, unknown>;
  const resolvedPlayback = await resolveViewerPlaybackForRow(latest, { hideUntilReady: true });
  return json({
    session: {
      ...viewerSessionWire(latest, resolvedPlayback),
      ownerUser,
      owner_user: ownerUser,
    },
  });
}

async function fetchViewerSession(url: URL, _authed: string, log: RequestLogContext) {
  const ownerID = String(url.searchParams.get('owner_user_id') ?? url.searchParams.get('user_id') ?? '').trim().toLowerCase();
  if (!ownerID) return badRequest('owner_user_id is required');
  setLogAccountScope(log, ownerID);

  const admin = serviceClient();
  const viewerID = _authed.trim().toLowerCase();
  if (viewerID !== ownerID && await hasMutualBlock(admin, viewerID, ownerID)) {
    return forbidden('You cannot view this live stream.');
  }
  await endStaleMobileSessions(admin, [ownerID]);
  // Apollo Radio broadcasts are audio for Apollo, not Scrolls live video. They
  // share this table, so the Scrolls-facing lookups have to exclude them or
  // going on air in Apollo makes the artist appear live on Scrolls too.
  const session = await admin.from('live_stream_sessions')
    .select('*')
    .eq('owner_user_id', ownerID)
    .eq('status', 'active')
    .neq('broadcast_kind', 'radio')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);

  if (!session.data) {
    return json({ session: null });
  }
  const row = session.data as Record<string, unknown>;
  const resolvedPlayback = await resolveViewerPlaybackForRow(row, { hideUntilReady: true });
  return json({ session: viewerSessionWire(row, resolvedPlayback) });
}

async function verifyViewerPassword(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const ownerID = String(payload.owner_user_id ?? payload.ownerUserID ?? payload.user_id ?? payload.userID ?? '').trim().toLowerCase();
  const password = normalizeViewerPassword(payload.password);
  if (!ownerID) return badRequest('owner_user_id is required');
  if (!password) return json({ verified: false });
  if (password.length > VIEWER_PASSWORD_MAX_CHARS) return badRequest('Password is too long.');
  setLogAccountScope(log, [authed, ownerID]);

  if (!checkViewerPasswordRateLimit(req, ownerID)) {
    return json({ verified: false, error: 'Too many password attempts. Try again shortly.' }, 429);
  }

  const admin = serviceClient();
  if (authed.trim().toLowerCase() !== ownerID && await hasMutualBlock(admin, authed, ownerID)) {
    return json({ verified: false });
  }
  await endStaleMobileSessions(admin, [ownerID]);
  const session = await admin.from('live_stream_sessions')
    .select('id, owner_user_id, viewer_password_hash')
    .eq('owner_user_id', ownerID)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (session.error) return badRequest(session.error.message);
  if (!session.data) return json({ verified: false });

  const row = session.data as Record<string, unknown>;
  const storedHash = String(row.viewer_password_hash ?? '').trim();
  if (!storedHash) return json({ verified: false });

  const verified = await verifyViewerPasswordHash(password, storedHash).catch(() => false);
  return json({ verified });
}

async function createSession(
  req: Request,
  authed: string,
  log: RequestLogContext,
  broadcastKind: BroadcastKind = 'video',
) {
  const payload = await req.json() as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Live stream scope denied');
  setLogAccountScope(log, actorID);

  if (broadcastKind === 'radio') {
    if (!actorHasRadioAccess(actorID, authed)) return forbidden('This account does not have Apollo Radio access.');
  } else {
    const hasLiveAccess = await actorHasLiveStreamAccess(actorID, authed);
    if (!hasLiveAccess) return unauthorized('Gold tier required for live streaming.');
  }

  const mode = broadcastKind === 'radio' ? 'obs' : normalizeLiveMode(payload.mode);
  const title = normalizeOptionalText(payload.title, TITLE_MAX_CHARS);
  const description = normalizeOptionalText(payload.description, DESCRIPTION_MAX_CHARS);
  const viewerPassword = broadcastKind === 'radio'
    ? null
    : normalizeViewerPassword(payload.viewer_password ?? payload.viewerPassword);
  if (viewerPassword && viewerPassword.length > VIEWER_PASSWORD_MAX_CHARS) {
    return badRequest('Viewer password is too long.');
  }
  const viewerPasswordHash = viewerPassword ? await hashViewerPassword(viewerPassword) : null;
  const createIdempotencyKey = normalizeIdempotencyKey(req.headers.get('x-idempotency-key') ?? payload.idempotency_key ?? payload.idempotencyKey);
  const rawTipGoal = payload.tip_goal ?? payload.tipGoal;
  const tipGoal = rawTipGoal != null && rawTipGoal !== ''
    ? (() => { const n = Number(rawTipGoal); return Number.isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : null; })()
    : null;

  const admin = serviceClient();
  const nowISO = new Date().toISOString();
  await endStaleMobileSessions(admin, [actorID]);

  if (createIdempotencyKey) {
    const existing = await admin.from('live_stream_sessions')
      .select('*')
      .eq('owner_user_id', actorID)
      .eq('broadcast_kind', broadcastKind)
      .eq('create_idempotency_key', createIdempotencyKey)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (existing.error) return badRequest(existing.error.message);
    if (existing.data) return json({ session: sessionWire(existing.data as Record<string, unknown>), idempotent: true });
  }

  const previouslyActive = await admin.from('live_stream_sessions')
    .select('id, cloudflare_uid')
    .eq('owner_user_id', actorID)
    .eq('status', 'active');
  if (previouslyActive.error) return badRequest(previouslyActive.error.message);

  const closed = await admin.from('live_stream_sessions')
    .update({ status: 'ended', ended_at: nowISO, ended_reason: 'superseded_by_new_session', updated_at: nowISO })
    .eq('owner_user_id', actorID)
    .eq('status', 'active');
  if (closed.error) return badRequest(closed.error.message);

  for (const row of (previouslyActive.data ?? []) as Array<Record<string, unknown>>) {
    try {
      await deleteCloudflareLiveInput(row.cloudflare_uid);
    } catch (error) {
      console.warn(`Closed stale live session but Cloudflare cleanup failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  let cfInput: CloudflareLiveInput;
  try {
    cfInput = await createCloudflareLiveInput(title, description);
  } catch (error) {
    return cloudflareUnavailable(`Cloudflare live input failed: ${error instanceof Error ? error.message : String(error)}`);
  }

  const streamKey = cfInput.streamKey;
  const ingestURL = cfInput.ingestURL;
  const playbackURL = cfInput.playbackURL;
  const inserted = await admin.from('live_stream_sessions')
    .insert({
      owner_user_id: actorID,
      mode,
      broadcast_kind: broadcastKind,
      title,
      description,
      tip_goal: tipGoal,
      viewer_password_hash: viewerPasswordHash,
      stream_key: streamKey,
      ingest_url: ingestURL,
      playback_url: playbackURL,
      cloudflare_uid: cfInput.uid,
      last_heartbeat_at: nowISO,
      create_idempotency_key: createIdempotencyKey,
      status: 'active',
      started_at: nowISO,
      updated_at: nowISO,
    })
    .select('*')
    .single();
  if (inserted.error || !inserted.data) {
    try {
      await deleteCloudflareLiveInput(cfInput.uid);
    } catch (cleanupError) {
      const cleanupMessage = cleanupError instanceof Error ? cleanupError.message : String(cleanupError);
      console.warn("Live session insert failed and Cloudflare cleanup failed: " + cleanupMessage);
    }

    if (createIdempotencyKey) {
      const existing = await admin.from("live_stream_sessions")
        .select("*")
        .eq("owner_user_id", actorID)
        .eq("broadcast_kind", broadcastKind)
        .eq("create_idempotency_key", createIdempotencyKey)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (!existing.error && existing.data) {
        return json({ session: sessionWire(existing.data as Record<string, unknown>), idempotent: true });
      }
    }

    return badRequest(inserted.error?.message ?? "Could not create live stream session.");
  }

  return json({ session: sessionWire(inserted.data as Record<string, unknown>) });
}

async function heartbeatSession(req: Request, authed: string, log: RequestLogContext) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized("Live stream scope denied");
  setLogAccountScope(log, actorID);

  const requestedSessionID = String(payload.session_id ?? payload.sessionID ?? "").trim();
  const admin = serviceClient();

  let lookup = admin.from("live_stream_sessions")
    .select("*")
    .eq("owner_user_id", actorID)
    .eq("status", "active")
    .eq("mode", "mobile")
    .order("started_at", { ascending: false })
    .limit(1);
  if (requestedSessionID) {
    lookup = lookup.eq("id", requestedSessionID);
  }

  const current = await lookup.maybeSingle();
  if (current.error) return badRequest(current.error.message);
  if (!current.data) return json({ ok: false, session: null, ended: true });

  const nowISO = new Date().toISOString();
  const touched = await admin.from("live_stream_sessions")
    .update({ last_heartbeat_at: nowISO, updated_at: nowISO })
    .eq("id", String(current.data.id ?? ""))
    .eq("status", "active")
    .select("*")
    .single();
  if (touched.error || !touched.data) {
    return badRequest(touched.error?.message ?? "Could not update live heartbeat.");
  }

  await endStaleMobileSessions(admin, [actorID]);
  return json({ ok: true, session: sessionWire(touched.data as Record<string, unknown>) });
}

async function endSession(
  req: Request,
  authed: string,
  log: RequestLogContext,
  broadcastKind: BroadcastKind = 'video',
) {
  const payload = await req.json() as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Live stream scope denied');
  setLogAccountScope(log, actorID);

  if (broadcastKind === 'radio') {
    if (!actorHasRadioAccess(actorID, authed)) return forbidden('This account does not have Apollo Radio access.');
  } else {
    const hasLiveAccess = await actorHasLiveStreamAccess(actorID, authed);
    if (!hasLiveAccess) return unauthorized('Gold tier required for live streaming.');
  }

  const requestedSessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  const admin = serviceClient();

  let lookup = admin.from('live_stream_sessions')
    .select('*')
    .eq('owner_user_id', actorID)
    .eq('broadcast_kind', broadcastKind)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1);
  if (requestedSessionID) {
    lookup = lookup.eq('id', requestedSessionID);
  }

  const current = await lookup.maybeSingle();
  if (current.error) return badRequest(current.error.message);
  if (!current.data) return json({ ok: true, session: null });

  const nowISO = new Date().toISOString();
  const ended = await admin.from('live_stream_sessions')
    .update({ status: 'ended', ended_at: nowISO, ended_reason: 'owner_ended', updated_at: nowISO })
    .eq('id', String(current.data.id ?? ''))
    .select('*')
    .single();
  if (ended.error || !ended.data) {
    return badRequest(ended.error?.message ?? 'Could not end live stream session.');
  }

  let warning: string | null = null;
  try {
    await deleteCloudflareLiveInput((current.data as Record<string, unknown>).cloudflare_uid);
  } catch (error) {
    warning = `Live session ended, but Cloudflare cleanup failed: ${error instanceof Error ? error.message : String(error)}`;
    console.warn(warning);
  }

  return json({ ok: true, session: sessionWire(ended.data as Record<string, unknown>), warning });
}

async function rotateSessionKey(
  req: Request,
  authed: string,
  log: RequestLogContext,
  broadcastKind: BroadcastKind = 'video',
) {
  const payload = await req.json() as Record<string, unknown>;
  const actorID = await resolvedActorID(authed, payload.user_id ?? payload.userID);
  if (!actorID) return unauthorized('Live stream scope denied');
  setLogAccountScope(log, actorID);

  if (broadcastKind === 'radio') {
    if (!actorHasRadioAccess(actorID, authed)) return forbidden('This account does not have Apollo Radio access.');
  } else {
    const hasLiveAccess = await actorHasLiveStreamAccess(actorID, authed);
    if (!hasLiveAccess) return unauthorized('Gold tier required for live streaming.');
  }

  const requestedSessionID = String(payload.session_id ?? payload.sessionID ?? '').trim();
  const admin = serviceClient();

  let lookup = admin.from('live_stream_sessions')
    .select('*')
    .eq('owner_user_id', actorID)
    .eq('broadcast_kind', broadcastKind)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1);
  if (requestedSessionID) {
    lookup = lookup.eq('id', requestedSessionID);
  }

  const current = await lookup.maybeSingle();
  if (current.error) return badRequest(current.error.message);
  if (!current.data) return notFound();

  const currentRecord = current.data as Record<string, unknown>;
  const title = normalizeOptionalText(currentRecord.title, TITLE_MAX_CHARS);
  const description = normalizeOptionalText(currentRecord.description, DESCRIPTION_MAX_CHARS);

  let cfInput: CloudflareLiveInput;
  try {
    cfInput = await createCloudflareLiveInput(title, description);
  } catch (error) {
    return cloudflareUnavailable(`Cloudflare live input failed: ${error instanceof Error ? error.message : String(error)}`);
  }

  const streamKey = cfInput.streamKey;
  const ingestURL = cfInput.ingestURL;
  const playbackURL = cfInput.playbackURL;
  const nowISO = new Date().toISOString();

  const updated = await admin.from('live_stream_sessions')
    .update({
      stream_key: streamKey,
      ingest_url: ingestURL,
      playback_url: playbackURL,
      cloudflare_uid: cfInput.uid,
      last_heartbeat_at: nowISO,
      updated_at: nowISO,
    })
    .eq('id', String(currentRecord.id ?? ''))
    .select('*')
    .single();
  if (updated.error || !updated.data) {
    try {
      await deleteCloudflareLiveInput(cfInput.uid);
    } catch (cleanupError) {
      const cleanupMessage = cleanupError instanceof Error ? cleanupError.message : String(cleanupError);
      console.warn("Stream key rotate failed and new Cloudflare cleanup failed: " + cleanupMessage);
    }
    return badRequest(updated.error?.message ?? "Could not rotate live stream key.");
  }

  let warning: string | null = null;
  try {
    await deleteCloudflareLiveInput(currentRecord.cloudflare_uid);
  } catch (error) {
    warning = `Stream key rotated, but old Cloudflare input cleanup failed: ${error instanceof Error ? error.message : String(error)}`;
    console.warn(warning);
  }

  return json({ session: sessionWire(updated.data as Record<string, unknown>), warning });
}

// ---------------------------------------------------------------------------
// GET /live/session/manifest-debug
//
// Debug-only endpoint for diagnosing livestream delivery issues.
// Probes Cloudflare lifecycle + HLS manifests TWICE (3 s apart) so you can
// tell mid-broadcast whether Cloudflare is advancing segments or frozen.
//
// Query params:
//   owner_user_id  – probe another user's active session (founder only)
//   session_id     – probe a specific session id (founder only for others)
//
// Returns JSON with:
//   session        – id, cloudflare_uid, playback_url, heartbeat age
//   lifecycle      – live, videoUID, raw payload, fetch latency
//   cfLiveInput    – Cloudflare API live-input status (connected / not)
//   inputManifest  – probe1 + probe2 of liveInputUID manifest, advancing?
//   videoManifest  – same for videoUID manifest (null if no videoUID)
//   advancing      – top-level bool: did ANY manifest advance?
// ---------------------------------------------------------------------------
async function debugManifest(url: URL, authed: string, log: RequestLogContext) {
  // Founder-gate for probing other users' sessions.
  const rawOwner = (url.searchParams.get('owner_user_id') ?? url.searchParams.get('user_id') ?? '').trim().toLowerCase();
  const rawSessionID = url.searchParams.get('session_id')?.trim() ?? '';
  const targetOwner = rawOwner || authed.trim().toLowerCase();
  const isSelf = targetOwner === authed.trim().toLowerCase();

  if (!isSelf && !isFounderUserID(authed)) {
    return unauthorized('Only founders can debug other users\' sessions.');
  }
  setLogAccountScope(log, targetOwner);

  const admin = serviceClient();

  // ── 1. Look up active session ─────────────────────────────────────────────
  let lookup = admin.from('live_stream_sessions')
    .select('id, owner_user_id, cloudflare_uid, playback_url, ingest_url, stream_key, mode, status, started_at, last_heartbeat_at')
    .eq('owner_user_id', targetOwner)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1);
  if (rawSessionID) {
    lookup = lookup.eq('id', rawSessionID);
  }

  const sessionResp = await lookup.maybeSingle();
  if (sessionResp.error) return badRequest(sessionResp.error.message);
  if (!sessionResp.data) {
    return json({ error: 'No active session found for this user.' }, 404);
  }

  const row = sessionResp.data as Record<string, unknown>;
  const cloudflareUID = String(row.cloudflare_uid ?? '').trim();
  const playbackURL = String(row.playback_url ?? '').trim();
  const lastHeartbeat = row.last_heartbeat_at ? String(row.last_heartbeat_at) : null;
  const heartbeatAgeMs = lastHeartbeat
    ? Date.now() - new Date(lastHeartbeat).getTime()
    : null;

  const sessionInfo = {
    id: String(row.id ?? ''),
    ownerUserID: String(row.owner_user_id ?? ''),
    cloudflareUID,
    playbackURL,
    ingestHost: (() => { try { return new URL(String(row.ingest_url ?? '')).host; } catch { return 'unknown'; } })(),
    mode: String(row.mode ?? ''),
    startedAt: String(row.started_at ?? ''),
    lastHeartbeatAt: lastHeartbeat,
    heartbeatAgeMs,
    heartbeatStale: heartbeatAgeMs != null ? heartbeatAgeMs > MOBILE_HEARTBEAT_STALE_MS : null,
  };

  // ── 2. Probe Cloudflare lifecycle ─────────────────────────────────────────
  const lifecycleResult = await (async () => {
    const lifecycleURL = parseLifecycleURL(playbackURL, cloudflareUID);
    if (!lifecycleURL) return { error: 'Could not build lifecycle URL', url: null };
    const t0 = Date.now();
    try {
      const resp = await fetch(lifecycleURL.toString(), {
        method: 'GET',
        headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' },
        signal: AbortSignal.timeout(5000),
      });
      const fetchMs = Date.now() - t0;
      const httpStatus = resp.status;
      let raw: Record<string, unknown> = {};
      try { raw = await resp.json() as Record<string, unknown>; } catch { /* ok */ }
      const videoUID = String(raw.videoUID ?? '').trim();
      const live = Boolean(raw.live ?? false) || videoUID.length > 0;
      return { url: lifecycleURL.toString(), httpStatus, fetchMs, live, videoUID: videoUID || null, isInput: raw.isInput ?? null, raw };
    } catch (e) {
      return { url: lifecycleURL.toString(), error: e instanceof Error ? e.message : String(e), fetchMs: Date.now() - t0 };
    }
  })();

  // ── 3. Probe Cloudflare Stream API for live-input connection status ────────
  const cfInputResult = await (async () => {
    if (!cloudflareUID || !CLOUDFLARE_ACCOUNT_ID || !CLOUDFLARE_API_TOKEN) {
      return { error: 'Cloudflare credentials not configured or no UID' };
    }
    const apiURL = `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs/${cloudflareUID}`;
    const t0 = Date.now();
    try {
      const resp = await fetch(apiURL, {
        method: 'GET',
        headers: { Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}` },
        signal: AbortSignal.timeout(6000),
      });
      const fetchMs = Date.now() - t0;
      const httpStatus = resp.status;
      let payload: Record<string, unknown> = {};
      try { payload = await resp.json() as Record<string, unknown>; } catch { /* ok */ }
      const result = (payload.result ?? {}) as Record<string, unknown>;
      const status = String(result.status ?? '').trim();
      const rtmpsURL = ((result.rtmps ?? {}) as Record<string, unknown>).url ?? null;
      return { url: apiURL, httpStatus, fetchMs, status, rtmpsURL, success: Boolean(payload.success ?? false) };
    } catch (e) {
      return { url: apiURL, error: e instanceof Error ? e.message : String(e), fetchMs: Date.now() - t0 };
    }
  })();

  // ── 4. HLS manifest probe helper ──────────────────────────────────────────
  async function probeManifest(manifestURL: string): Promise<{
    url: string; httpStatus: number; fetchMs: number;
    segmentCount: number; mediaSequence: number | null;
    targetDuration: number | null; hasEndList: boolean;
    firstSegment: string | null; lastSegment: string | null;
    rawSnippet: string; error?: string;
  }> {
    const t0 = Date.now();
    try {
      const resp = await fetch(manifestURL, {
        headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' },
        signal: AbortSignal.timeout(5000),
      });
      const fetchMs = Date.now() - t0;
      const httpStatus = resp.status;
      const body = httpStatus === 200 ? await resp.text() : '';
      const lines = body.split('\n').map((l) => l.trim()).filter(Boolean);

      let segmentCount = 0;
      let mediaSequence: number | null = null;
      let targetDuration: number | null = null;
      let hasEndList = false;
      let firstSegment: string | null = null;
      let lastSegment: string | null = null;

      for (const line of lines) {
        if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
          mediaSequence = parseInt(line.replace('#EXT-X-MEDIA-SEQUENCE:', '').trim(), 10);
        } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
          targetDuration = parseInt(line.replace('#EXT-X-TARGETDURATION:', '').trim(), 10);
        } else if (line === '#EXT-X-ENDLIST') {
          hasEndList = true;
        } else if (!line.startsWith('#') && (line.includes('.ts') || line.includes('seg') || line.startsWith('http'))) {
          segmentCount++;
          if (firstSegment === null) firstSegment = line.slice(0, 100);
          lastSegment = line.slice(0, 100);
        }
      }

      const rawSnippet = body.slice(0, 800);
      return { url: manifestURL, httpStatus, fetchMs, segmentCount, mediaSequence, targetDuration, hasEndList, firstSegment, lastSegment, rawSnippet };
    } catch (e) {
      return {
        url: manifestURL, httpStatus: 0, fetchMs: Date.now() - t0,
        segmentCount: 0, mediaSequence: null, targetDuration: null,
        hasEndList: false, firstSegment: null, lastSegment: null,
        rawSnippet: '', error: e instanceof Error ? e.message : String(e),
      };
    }
  }

  // ── 5. Probe input + video manifests (probe1), wait 3 s, then probe2 ─────
  const videoUID = (lifecycleResult as Record<string, unknown>).videoUID as string | null ?? null;

  const inputManifestURL = playbackURL || (cloudflareUID && CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN
    ? `${normalizedBase(CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN, 'https://customer-placeholder.cloudflarestream.com')}/${cloudflareUID}/manifest/video.m3u8`
    : null);

  const videoManifestURL = videoUID && inputManifestURL
    ? (() => { try { const p = new URL(inputManifestURL); return `${p.protocol}//${p.host}/${videoUID}/manifest/video.m3u8`; } catch { return null; } })()
    : null;

  const [inputProbe1, videoProbe1] = await Promise.all([
    inputManifestURL ? probeManifest(inputManifestURL) : Promise.resolve(null),
    videoManifestURL ? probeManifest(videoManifestURL) : Promise.resolve(null),
  ]);

  // Wait 3 s, then re-probe to see if sequence numbers advance.
  await new Promise((resolve) => setTimeout(resolve, 3000));

  const [inputProbe2, videoProbe2] = await Promise.all([
    inputManifestURL ? probeManifest(inputManifestURL) : Promise.resolve(null),
    videoManifestURL ? probeManifest(videoManifestURL) : Promise.resolve(null),
  ]);

  // ── 6. Assess advancement ─────────────────────────────────────────────────
  function didAdvance(p1: Awaited<ReturnType<typeof probeManifest>> | null, p2: Awaited<ReturnType<typeof probeManifest>> | null): boolean | null {
    if (!p1 || !p2) return null;
    if (p1.httpStatus !== 200 || p2.httpStatus !== 200) return null;
    if (p1.mediaSequence !== null && p2.mediaSequence !== null) {
      return p2.mediaSequence > p1.mediaSequence;
    }
    if (p1.segmentCount !== null && p2.segmentCount !== null) {
      return p2.segmentCount > p1.segmentCount;
    }
    return null;
  }

  const inputAdvancing = didAdvance(inputProbe1, inputProbe2);
  const videoAdvancing = didAdvance(videoProbe1, videoProbe2);
  const anyAdvancing = inputAdvancing === true || videoAdvancing === true;

  // ── 7. Diagnosis hint ─────────────────────────────────────────────────────
  const diagnosis = (() => {
    const lc = lifecycleResult as Record<string, unknown>;
    if (!lc.live) return 'lifecycle_not_live: Cloudflare does not see an active RTMP stream. Check broadcaster connection.';
    if (!lc.videoUID) return 'live_no_videoUID: Cloudflare sees RTMP connected but has no active recording yet (may be very early in startup).';
    if ((inputProbe1?.httpStatus ?? 0) === 204 && (videoProbe1?.httpStatus ?? 0) === 204) {
      return 'manifest_204: Both manifests return 204 No Content — Cloudflare has not generated any HLS segments yet despite being live.';
    }
    if (inputProbe1?.hasEndList || videoProbe1?.hasEndList) {
      return 'manifest_ended: Manifest has EXT-X-ENDLIST — Cloudflare thinks the stream ended. New RTMP connection may be needed.';
    }
    if (!anyAdvancing && (inputProbe1?.httpStatus === 200 || videoProbe1?.httpStatus === 200)) {
      return 'manifest_frozen: Manifests return 200 but segments did NOT advance in 3 s. Cloudflare received video but the encoder stalled or RTMP dropped after the first keyframe.';
    }
    if (anyAdvancing) {
      return 'healthy: Manifest is advancing — stream is live and HLS segments are being generated. Viewer issue is downstream.';
    }
    return 'unknown: Could not determine manifest state.';
  })();

  return json({
    diagnosedAt: new Date().toISOString(),
    session: sessionInfo,
    lifecycle: lifecycleResult,
    cfLiveInput: cfInputResult,
    inputManifest: inputManifestURL ? {
      url: inputManifestURL,
      probe1: inputProbe1,
      probe2: inputProbe2,
      advancing: inputAdvancing,
    } : null,
    videoManifest: videoManifestURL ? {
      url: videoManifestURL,
      probe1: videoProbe1,
      probe2: videoProbe2,
      advancing: videoAdvancing,
    } : null,
    advancing: anyAdvancing,
    diagnosis,
  });
}
