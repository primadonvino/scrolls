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

type JsonRecord = Record<string, unknown>;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const RELEASE_TYPES = new Set(["single", "ep", "album"]);
const RELEASE_STATUSES = new Set(["draft", "published"]);
const PLAY_SOURCES = new Set(["web", "ios", "android", "daw"]);

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

    if (!authed) return unauthorized();
    if (req.method === "POST" && route === "releases") {
      return await createRelease(req, authed);
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

function mediaRef(value: unknown): {
  provider: string;
  bucket: string | null;
  objectKey: string;
  mimeType: string | null;
  byteSize: number | null;
} | null {
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

async function createRelease(req: Request, ownerID: string): Promise<Response> {
  const payload = await req.json() as JsonRecord;
  const title = text(payload.title, 160);
  const trackTitle = text(payload.trackTitle ?? payload.track_title ?? payload.title, 160);
  const track = mediaRef(payload.track ?? payload.trackAsset ?? payload.track_asset);
  const cover = mediaRef(payload.cover ?? payload.coverAsset ?? payload.cover_asset);
  const status = releaseStatus(payload.status);

  if (!title || !trackTitle) return badRequest("Release and track titles are required.");
  if (!track) return badRequest("A master track asset is required.");

  const ownerPrefix = `music/${ownerID.toLowerCase()}/`;
  if (!track.objectKey.startsWith(ownerPrefix)) {
    return badRequest("Track asset is outside the signed-in user's namespace.");
  }
  if (cover && !cover.objectKey.startsWith(ownerPrefix)) {
    return badRequest("Cover asset is outside the signed-in user's namespace.");
  }

  const duration = numberOrNull(payload.durationSeconds ?? payload.duration_seconds);
  if (duration !== null && (duration <= 0 || duration > 24 * 60 * 60)) {
    return badRequest("Invalid track duration.");
  }
  const bpm = numberOrNull(payload.bpm);
  if (bpm !== null && (bpm <= 0 || bpm >= 400)) return badRequest("Invalid BPM.");

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

  const result = await admin.rpc("apollo_create_release", {
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
    p_track_title: trackTitle,
    p_duration_seconds: duration,
    p_bpm: bpm,
    p_musical_key: nullableText(payload.musicalKey ?? payload.musical_key, 32),
    p_track_provider: track.provider,
    p_track_bucket: track.bucket,
    p_track_object_key: track.objectKey,
    p_track_mime_type: track.mimeType,
    p_track_byte_size: track.byteSize,
    p_scrolls_post_id: scrollsPostID,
    p_status: status,
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
