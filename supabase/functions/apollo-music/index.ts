import {
  badRequest,
  currentUserId,
  json,
  notFound,
  optionsResponse,
  serverError,
  setLogAccountScope,
  setLogAuthUser,
  serviceClient,
  unauthorized,
  withRequestLogging,
} from "../_shared/http.ts";
import { canActAsAccount, resolveScopedAccountID } from "../_shared/account_scope.ts";

type JsonRecord = Record<string, unknown>;

type MediaReference = {
  provider: string;
  bucket: string | null;
  objectKey: string;
  mimeType: string | null;
  byteSize: number | null;
};

type NormalizedTrack = {
  title: string;
  trackNumber: number;
  durationSeconds: number | null;
  bpm: number | null;
  musicalKey: string | null;
  explicit: boolean;
  isrc: string | null;
  lyrics: string | null;
  credits: unknown[];
  asset: MediaReference;
};

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const RELEASE_TYPES = new Set(["single", "ep", "album"]);
const RELEASE_STATUSES = new Set(["draft", "published"]);
const PLAY_SOURCES = new Set(["web", "ios", "android", "daw"]);
const RELEASE_SOURCES = new Set(["apollo-daw", "apollo-ios", "apollo-web"]);

Deno.serve((req) => withRequestLogging(req, async (log) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const route = parts[parts.length - 1] ?? "";
    const authed = await currentUserId(req);
    setLogAuthUser(log, authed);
    setLogAccountScope(log, authed ?? "public-music");

    if (req.method === "POST" && route === "plays") {
      return await recordPlay(req, authed);
    }
    if (req.method === "POST" && route === "ad-impressions") {
      return await recordAdImpression(req, authed);
    }

    if (!authed) return unauthorized();
    if (req.method === "POST" && route === "releases") {
      return await createRelease(req, authed);
    }
    if (req.method === "DELETE" && route === "tracks") {
      return await deleteTrack(req, authed);
    }
    if (req.method === "DELETE" && route === "releases") {
      return await deleteRelease(req, authed);
    }
    if (req.method === "PATCH" && route === "publish") {
      return await publishRelease(req, authed);
    }
    if (req.method === "GET" && route === "analytics") {
      return await releaseAnalytics(url, authed);
    }

    return notFound();
  } catch (error) {
    return serverError(error);
  }
}));

function text(value: unknown, maxLength: number): string {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function nullableText(value: unknown, maxLength: number): string | null {
  return text(value, maxLength) || null;
}

function numberOrNull(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function integerOrNull(value: unknown): number | null {
  const parsed = numberOrNull(value);
  return parsed === null ? null : Math.max(0, Math.round(parsed));
}

function booleanValue(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes"].includes(normalized)) return true;
    if (["false", "0", "no"].includes(normalized)) return false;
  }
  return fallback;
}

function uuid(value: unknown): string | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  return UUID_PATTERN.test(normalized) ? normalized : null;
}

function normalizedHandle(value: unknown, ownerID: string): string {
  const cleaned = String(value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, "-")
    .replace(/^[^a-z0-9]+|[^a-z0-9]+$/g, "")
    .slice(0, 32);
  if (cleaned.length >= 2) return cleaned;
  return `artist-${ownerID.replace(/-/g, "").slice(0, 12)}`;
}

function releaseType(value: unknown): "single" | "ep" | "album" {
  const normalized = String(value ?? "single").trim().toLowerCase();
  return RELEASE_TYPES.has(normalized) ? normalized as "single" | "ep" | "album" : "single";
}

function releaseStatus(value: unknown): "draft" | "published" {
  const normalized = String(value ?? "published").trim().toLowerCase();
  return RELEASE_STATUSES.has(normalized) ? normalized as "draft" | "published" : "published";
}

function mediaRef(value: unknown): MediaReference | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as JsonRecord;
  const objectKey = text(record.objectKey ?? record.object_key, 512);
  if (!objectKey) return null;
  return {
    provider: text(record.provider, 40) || "r2",
    bucket: nullableText(record.bucket, 160),
    objectKey,
    mimeType: nullableText(record.mimeType ?? record.mime_type, 120),
    byteSize: integerOrNull(record.byteSize ?? record.byte_size),
  };
}

function musicOwnerIDFromObjectKey(objectKey: string | null | undefined): string {
  const segments = String(objectKey ?? "").split("/").filter(Boolean);
  if (segments[0]?.toLowerCase() !== "music") return "";
  return String(segments[1] ?? "").trim().toLowerCase();
}

/**
 * Storage this user owns.
 *
 * Apollo writes new media under `music/<owner>/...`, but a back catalogue
 * published through Scrolls is spread across roots that predate it -
 * `posts/<owner>/...` for a post's own asset, and older releases with the owner
 * id as the very first segment. Requiring one fixed prefix would mean copying
 * hundreds of megabytes of audio to a new path just to import metadata.
 *
 * The rule is therefore positional rather than a fixed prefix: the owner id has
 * to be the first or second path segment. That keeps the property this check
 * exists for - you cannot point a release at another user's objects - while
 * accepting every layout an account may already have.
 */
function isOwnedObjectKey(objectKey: string, ownerID: string): boolean {
  const owner = ownerID.trim().toLowerCase();
  if (!owner) return false;
  const segments = objectKey.toLowerCase().split("/").filter((part) => part.length > 0);
  // A bare key with no directory cannot belong to anyone in particular.
  if (segments.length < 2) return false;
  return segments[0] === owner || segments[1] === owner;
}

function normalizeTracks(payload: JsonRecord, ownerID: string): NormalizedTrack[] | Response {
  const rawTracks = Array.isArray(payload.tracks)
    ? payload.tracks
    : [{
      title: payload.trackTitle ?? payload.track_title ?? payload.title,
      trackNumber: 1,
      durationSeconds: payload.durationSeconds ?? payload.duration_seconds,
      bpm: payload.bpm,
      musicalKey: payload.musicalKey ?? payload.musical_key,
      explicit: payload.explicit,
      asset: payload.track ?? payload.trackAsset ?? payload.track_asset,
    }];

  if (rawTracks.length < 1 || rawTracks.length > 100) {
    return badRequest("A release requires between 1 and 100 tracks.");
  }

  const usedTrackNumbers = new Set<number>();
  const tracks: NormalizedTrack[] = [];

  for (let index = 0; index < rawTracks.length; index += 1) {
    const raw = rawTracks[index];
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      return badRequest(`Track ${index + 1} is invalid.`);
    }
    const record = raw as JsonRecord;
    const title = text(record.title, 160);
    const asset = mediaRef(record.asset ?? record.track ?? record.trackAsset ?? record.track_asset);
    if (!title) return badRequest(`Track ${index + 1} requires a title.`);
    if (!asset) return badRequest(`Track ${index + 1} requires a master asset.`);
    if (!isOwnedObjectKey(asset.objectKey, ownerID)) {
      return badRequest(`Track ${index + 1} is outside the signed-in user's namespace.`);
    }

    const trackNumber = integerOrNull(record.trackNumber ?? record.track_number) ?? index + 1;
    if (trackNumber < 1 || trackNumber > 999 || usedTrackNumbers.has(trackNumber)) {
      return badRequest(`Track ${index + 1} has an invalid or duplicate track number.`);
    }
    usedTrackNumbers.add(trackNumber);

    const duration = numberOrNull(record.durationSeconds ?? record.duration_seconds);
    if (duration !== null && (duration <= 0 || duration > 24 * 60 * 60)) {
      return badRequest(`Track ${index + 1} has an invalid duration.`);
    }
    const bpm = numberOrNull(record.bpm);
    if (bpm !== null && (bpm <= 0 || bpm >= 400)) {
      return badRequest(`Track ${index + 1} has an invalid BPM.`);
    }

    const rawCredits = Array.isArray(record.credits) ? record.credits : [];
    if (rawCredits.length > 100 || JSON.stringify(rawCredits).length > 20_000) {
      return badRequest(`Track ${index + 1} has too much credit metadata.`);
    }

    tracks.push({
      title,
      trackNumber,
      durationSeconds: duration,
      bpm,
      musicalKey: nullableText(record.musicalKey ?? record.musical_key, 32),
      explicit: booleanValue(record.explicit, booleanValue(payload.explicit)),
      isrc: nullableText(record.isrc, 64),
      lyrics: nullableText(record.lyrics, 200_000),
      credits: rawCredits,
      asset,
    });
  }

  return tracks;
}

async function createRelease(req: Request, authedID: string): Promise<Response> {
  const contentLength = Number(req.headers.get("content-length") ?? 0);
  if (contentLength > 2_000_000) return badRequest("Release metadata is too large.");
  const payload = await req.json() as JsonRecord;
  const cover = mediaRef(payload.cover ?? payload.coverAsset ?? payload.cover_asset);
  const firstTrack = Array.isArray(payload.tracks) && payload.tracks[0]
    && typeof payload.tracks[0] === "object" && !Array.isArray(payload.tracks[0])
    ? payload.tracks[0] as JsonRecord
    : null;
  const firstTrackAsset = firstTrack
    ? mediaRef(firstTrack.asset ?? firstTrack.track ?? firstTrack.trackAsset ?? firstTrack.track_asset)
    : null;
  const explicitOwnerID = text(
    payload.ownerID ?? payload.owner_id ?? payload.authorID ?? payload.author_id,
    64,
  ).toLowerCase();
  // Older clients did not send authorID to this final catalog step. Their
  // signed asset path still identifies the account, and the scope resolver
  // below verifies that the authenticated user is allowed to act for it.
  const requestedOwnerID = explicitOwnerID
    || musicOwnerIDFromObjectKey(cover?.objectKey ?? firstTrackAsset?.objectKey);
  const ownerID = await resolveScopedAccountID(authedID, requestedOwnerID);
  if (!ownerID) return unauthorized("You cannot publish music for that account.");
  const title = text(payload.title, 160);
  const status = releaseStatus(payload.status);

  if (!title) return badRequest("A release title is required.");
  const tracks = normalizeTracks(payload, ownerID);
  if (tracks instanceof Response) return tracks;

  if (cover && !isOwnedObjectKey(cover.objectKey, ownerID)) {
    return badRequest("Cover asset is outside the signed-in user's namespace.");
  }

  const admin = serviceClient();
  const profile = await admin.from("account_profiles")
    .select("id,username,display_name")
    .eq("id", ownerID)
    .maybeSingle();
  if (profile.error) throw profile.error;

  const fallbackProfile = profile.data ?? (await admin.from("users")
    .select("id,username,display_name")
    .eq("id", ownerID)
    .single()).data;
  if (!fallbackProfile) return badRequest("Apollo profile not found.");

  const existingArtist = await admin.from("music_artists")
    .select("handle")
    .eq("owner_id", ownerID)
    .maybeSingle();
  if (existingArtist.error) throw existingArtist.error;

  let handle = existingArtist.data?.handle
    ?? normalizedHandle(payload.artistHandle ?? payload.artist_handle ?? fallbackProfile.username, ownerID);
  if (!existingArtist.data) {
    const collision = await admin.from("music_artists")
      .select("owner_id")
      .eq("handle", handle)
      .neq("owner_id", ownerID)
      .maybeSingle();
    if (collision.error) throw collision.error;
    if (collision.data) handle = normalizedHandle(`artist-${ownerID.replace(/-/g, "")}`, ownerID);
  }

  const displayName = text(
    payload.artistDisplayName ?? payload.artist_display_name
      ?? fallbackProfile.display_name ?? fallbackProfile.username,
    80,
  ) || handle;

  const scrollsPostIDRaw = payload.scrollsPostID ?? payload.scrolls_post_id;
  const scrollsPostID = scrollsPostIDRaw ? uuid(scrollsPostIDRaw) : null;
  if (scrollsPostIDRaw && !scrollsPostID) return badRequest("Invalid Scrolls post ID.");

  const clientReleaseIDRaw = payload.clientReleaseID ?? payload.client_release_id;
  const clientReleaseID = clientReleaseIDRaw ? uuid(clientReleaseIDRaw) : null;
  if (clientReleaseIDRaw && !clientReleaseID) return badRequest("Invalid client release ID.");

  const sourceCandidate = text(payload.sourceApp ?? payload.source_app, 40).toLowerCase();
  const sourceApp = RELEASE_SOURCES.has(sourceCandidate) ? sourceCandidate : "apollo-daw";

  const result = await admin.rpc("apollo_create_release_v2", {
    p_owner_id: ownerID,
    p_artist_handle: handle,
    p_artist_display_name: displayName,
    p_title: title,
    p_release_type: releaseType(payload.releaseType ?? payload.release_type),
    p_genre: nullableText(payload.genre, 80),
    p_description: nullableText(payload.description ?? payload.caption, 4000),
    p_explicit: Boolean(payload.explicit ?? false),
    p_cover_provider: cover?.provider ?? null,
    p_cover_bucket: cover?.bucket ?? null,
    p_cover_object_key: cover?.objectKey ?? null,
    p_tracks: tracks,
    p_scrolls_post_id: scrollsPostID,
    p_client_release_id: clientReleaseID,
    p_status: status,
    p_source_app: sourceApp,
  });
  if (result.error) return badRequest(result.error.message);

  return json({ ok: true, ...result.data }, result.data?.idempotent ? 200 : 201);
}

async function publishRelease(req: Request, ownerID: string): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const releaseID = uuid(payload.releaseID ?? payload.release_id);
  if (!releaseID) return badRequest("Valid releaseID required.");

  const admin = serviceClient();
  const updated = await admin.from("music_releases")
    .update({ status: "published", published_at: new Date().toISOString() })
    .eq("id", releaseID)
    .eq("owner_id", ownerID)
    .in("status", ["draft", "published"])
    .select("id,status,published_at")
    .maybeSingle();
  if (updated.error) throw updated.error;
  if (!updated.data) return notFound();
  return json({ release: updated.data });
}

async function deleteTrack(req: Request, authedID: string): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const trackID = uuid(payload.trackID ?? payload.track_id);
  if (!trackID) return badRequest("Valid trackID required.");

  const admin = serviceClient();
  const track = await admin.from("music_tracks")
    .select("id,release_id,owner_id")
    .eq("id", trackID)
    .maybeSingle();
  if (track.error) throw track.error;
  if (!track.data) return notFound();

  const ownerID = String(track.data.owner_id ?? "").trim().toLowerCase();
  if (!ownerID || !await canActAsAccount(authedID, ownerID)) return unauthorized();

  const visibleTracks = await admin.from("music_tracks")
    .select("id", { count: "exact", head: true })
    .eq("release_id", track.data.release_id);
  if (visibleTracks.error) throw visibleTracks.error;
  if ((visibleTracks.count ?? 0) <= 1) {
    return badRequest("A release must keep at least one song.");
  }

  const deleted = await admin.from("music_tracks")
    .delete()
    .eq("id", trackID)
    .eq("owner_id", ownerID);
  if (deleted.error) throw deleted.error;

  const remaining = await admin.from("music_tracks")
    .select("id,track_number")
    .eq("release_id", track.data.release_id)
    .order("track_number", { ascending: true });
  if (remaining.error) throw remaining.error;
  for (let index = 0; index < (remaining.data ?? []).length; index += 1) {
    const row = remaining.data![index];
    const trackNumber = index + 1;
    if (row.track_number === trackNumber) continue;
    const renumbered = await admin.from("music_tracks")
      .update({ track_number: trackNumber })
      .eq("id", row.id)
      .eq("owner_id", ownerID);
    if (renumbered.error) throw renumbered.error;
  }
  return json({ ok: true, trackID, releaseID: track.data.release_id });
}

async function deleteRelease(req: Request, authedID: string): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const releaseID = uuid(payload.releaseID ?? payload.release_id);
  if (!releaseID) return badRequest("Valid releaseID required.");

  const admin = serviceClient();
  const release = await admin.from("music_releases")
    .select("id,owner_id,scrolls_post_id")
    .eq("id", releaseID)
    .maybeSingle();
  if (release.error) throw release.error;
  if (!release.data) return notFound();

  const ownerID = String(release.data.owner_id ?? "").trim().toLowerCase();
  if (!ownerID || !await canActAsAccount(authedID, ownerID)) return unauthorized();

  // Foreign keys cascade through tracks, assets, likes, library entries and
  // play events. Storage is handled by the linked Scrolls post deletion or the
  // orphan sweep, so this endpoint never accepts a caller-supplied object key.
  const deleted = await admin.from("music_releases")
    .delete()
    .eq("id", releaseID)
    .eq("owner_id", ownerID)
    .select("id")
    .maybeSingle();
  if (deleted.error) throw deleted.error;
  if (!deleted.data) return notFound();

  return json({
    ok: true,
    releaseID,
    scrollsPostID: release.data.scrolls_post_id ?? null,
  });
}

async function releaseAnalytics(url: URL, ownerID: string): Promise<Response> {
  const releaseID = uuid(url.searchParams.get("releaseID") ?? url.searchParams.get("release_id"));
  if (!releaseID) return badRequest("Valid releaseID required.");

  const admin = serviceClient();
  const tracks = await admin.from("music_tracks")
    .select("id,title")
    .eq("release_id", releaseID)
    .eq("owner_id", ownerID)
    .order("track_number");
  if (tracks.error) throw tracks.error;
  if (!tracks.data?.length) return notFound();

  const totals = await Promise.all(tracks.data.map(async (track) => {
    const result = await admin.from("music_play_events")
      .select("id", { count: "exact", head: true })
      .eq("track_id", track.id);
    if (result.error) throw result.error;
    return { trackID: track.id, title: track.title, plays: result.count ?? 0 };
  }));

  return json({
    releaseID,
    totalPlays: totals.reduce((sum, track) => sum + track.plays, 0),
    tracks: totals,
  });
}

async function recordPlay(req: Request, userID: string | null): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const trackID = uuid(payload.trackID ?? payload.track_id);
  const sessionID = uuid(payload.sessionID ?? payload.session_id);
  if (!trackID || !sessionID) return badRequest("Valid trackID and sessionID are required.");

  const requestedMS = integerOrNull(payload.msPlayed ?? payload.ms_played);
  if (requestedMS === null) return badRequest("msPlayed is required.");

  const admin = serviceClient();
  const trackResult = await admin.from("music_tracks")
    .select("id,duration_seconds,music_releases!inner(status,published_at)")
    .eq("id", trackID)
    .maybeSingle();
  if (trackResult.error) throw trackResult.error;
  if (!trackResult.data) return notFound();

  const releaseValue = trackResult.data.music_releases as unknown;
  const release = Array.isArray(releaseValue) ? releaseValue[0] : releaseValue;
  const releaseRow = release as JsonRecord | null;
  const publishedAt = releaseRow?.published_at ? new Date(String(releaseRow.published_at)) : null;
  if (releaseRow?.status !== "published" || !publishedAt || publishedAt > new Date()) {
    return notFound();
  }

  const durationSeconds = Number(trackResult.data.duration_seconds ?? 0);
  const durationMS = durationSeconds > 0 ? Math.round(durationSeconds * 1000) : 0;
  const acceptedMS = Math.min(requestedMS, durationMS > 0 ? durationMS : 6 * 60 * 60 * 1000);
  const thresholdMS = durationMS > 0
    ? Math.min(30_000, Math.max(5_000, Math.round(durationMS * 0.5)))
    : 30_000;
  if (acceptedMS < thresholdMS) {
    return json({ counted: false, reason: "listen-threshold" });
  }

  const listenerHash = await playListenerHash(req, userID);
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const hourly = await admin.from("music_play_events")
    .select("id", { count: "exact", head: true })
    .eq("listener_hash", listenerHash)
    .gte("played_at", hourAgo);
  if (hourly.error) throw hourly.error;
  if ((hourly.count ?? 0) >= 120) return json({ counted: false, reason: "rate-limit" }, 429);

  const sameTrack = await admin.from("music_play_events")
    .select("id", { count: "exact", head: true })
    .eq("listener_hash", listenerHash)
    .eq("track_id", trackID)
    .gte("played_at", dayAgo);
  if (sameTrack.error) throw sameTrack.error;
  if ((sameTrack.count ?? 0) >= 5) return json({ counted: false, reason: "track-rate-limit" });

  const sourceRaw = String(payload.source ?? "web").trim().toLowerCase();
  const source = PLAY_SOURCES.has(sourceRaw) ? sourceRaw : "web";
  const inserted = await admin.from("music_play_events").insert({
    track_id: trackID,
    user_id: userID,
    session_id: sessionID,
    listener_hash: listenerHash,
    ms_played: acceptedMS,
    completed: durationMS > 0 && acceptedMS >= Math.round(durationMS * 0.9),
    source,
  });
  if (inserted.error) {
    if (inserted.error.code === "23505") return json({ counted: false, reason: "duplicate" });
    throw inserted.error;
  }

  return json({ counted: true });
}

async function recordAdImpression(req: Request, userID: string | null): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const adID = uuid(payload.adID ?? payload.ad_id);
  const sessionID = uuid(payload.sessionID ?? payload.session_id);
  if (!adID || !sessionID) return badRequest("Valid adID and sessionID are required.");

  const requestedMS = integerOrNull(payload.msPlayed ?? payload.ms_played);
  if (requestedMS === null) return badRequest("msPlayed is required.");

  const admin = serviceClient();
  const adResult = await admin.from("music_ads")
    .select("id,duration_seconds,is_active,starts_at,ends_at")
    .eq("id", adID)
    .maybeSingle();
  if (adResult.error) throw adResult.error;
  if (!adResult.data || !adResult.data.is_active) return notFound();

  const durationSeconds = Number(adResult.data.duration_seconds ?? 0);
  const durationMS = durationSeconds > 0 ? Math.round(durationSeconds * 1000) : 0;
  const acceptedMS = Math.min(requestedMS, durationMS > 0 ? durationMS : 30 * 60 * 1000);
  if (acceptedMS < 3_000) return json({ counted: false, reason: "listen-threshold" });

  const now = Date.now();
  const startsAt = adResult.data.starts_at ? new Date(adResult.data.starts_at).getTime() : null;
  const endsAt = adResult.data.ends_at ? new Date(adResult.data.ends_at).getTime() : null;
  const endGraceMS = durationMS > 0 ? durationMS : 5 * 60 * 1000;
  if ((startsAt !== null && startsAt > now) || (endsAt !== null && endsAt + endGraceMS < now)) {
    return notFound();
  }

  const listenerHash = await playListenerHash(req, userID);
  const completed = durationMS > 0 && acceptedMS >= Math.round(durationMS * 0.9);
  const existing = await admin.from("music_ad_impressions")
    .select("id,listener_hash,ms_played,completed")
    .eq("ad_id", adID)
    .eq("session_id", sessionID)
    .maybeSingle();
  if (existing.error) throw existing.error;

  if (existing.data) {
    if (existing.data.listener_hash !== listenerHash) {
      return json({ counted: false, reason: "duplicate" });
    }
    const nextMS = Math.max(Number(existing.data.ms_played ?? 0), acceptedMS);
    const nextCompleted = Boolean(existing.data.completed) || completed;
    if (nextMS === existing.data.ms_played && nextCompleted === existing.data.completed) {
      return json({ counted: true, updated: false });
    }
    const updated = await admin.from("music_ad_impressions")
      .update({ ms_played: nextMS, completed: nextCompleted })
      .eq("id", existing.data.id);
    if (updated.error) throw updated.error;
    return json({ counted: true, updated: true });
  }

  const hourAgo = new Date(now - 60 * 60 * 1000).toISOString();
  const dayAgo = new Date(now - 24 * 60 * 60 * 1000).toISOString();
  const hourly = await admin.from("music_ad_impressions")
    .select("id", { count: "exact", head: true })
    .eq("listener_hash", listenerHash)
    .gte("created_at", hourAgo);
  if (hourly.error) throw hourly.error;
  if ((hourly.count ?? 0) >= 30) return json({ counted: false, reason: "rate-limit" }, 429);

  const sameAd = await admin.from("music_ad_impressions")
    .select("id", { count: "exact", head: true })
    .eq("listener_hash", listenerHash)
    .eq("ad_id", adID)
    .gte("created_at", dayAgo);
  if (sameAd.error) throw sameAd.error;
  if ((sameAd.count ?? 0) >= 3) return json({ counted: false, reason: "ad-rate-limit" });

  const sourceRaw = String(payload.source ?? "web").trim().toLowerCase();
  const source = PLAY_SOURCES.has(sourceRaw) ? sourceRaw : "web";
  const inserted = await admin.from("music_ad_impressions").insert({
    ad_id: adID,
    user_id: userID,
    session_id: sessionID,
    listener_hash: listenerHash,
    ms_played: acceptedMS,
    completed,
    source,
  });
  if (inserted.error) {
    if (inserted.error.code === "23505") return json({ counted: false, reason: "duplicate" });
    throw inserted.error;
  }

  return json({ counted: true });
}

async function playListenerHash(req: Request, userID: string | null): Promise<string> {
  const forwarded = req.headers.get("cf-connecting-ip")
    ?? req.headers.get("x-forwarded-for")?.split(",")[0]
    ?? "unknown";
  const day = new Date().toISOString().slice(0, 10);
  const salt = Deno.env.get("MUSIC_PLAY_HASH_SALT")
    ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    ?? "apollo";
  const bytes = new TextEncoder().encode(`${day}|${forwarded.trim()}|${userID ?? "anon"}|${salt}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((value) => value.toString(16).padStart(2, "0")).join("");
}
