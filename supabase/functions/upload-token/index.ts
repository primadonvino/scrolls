import {
  badRequest,
  currentUserId,
  json,
  notFound,
  optionsResponse,
  serverError,
  setLogAccountScope,
  setLogAuthUser,
  unauthorized,
  withRequestLogging,
} from "../_shared/http.ts";
import { canActAsAccount } from "../_shared/account_scope.ts";
import { createR2PresignedUploadURL, ensureR2BucketCors } from "./r2.ts";

type AllowedMediaType = {
  contentType: string;
  maxBytes: number;
};

const MAX_URL_TTL_SECONDS = 300;
const DEFAULT_URL_TTL_SECONDS = 300;
const R2_WEB_UPLOAD_ALLOWED_ORIGINS = [
  "https://scrolls.adastra.love",
  "https://scrolls-web.vercel.app",
  "http://localhost:3000",
];
const R2_CORS_SYNC_INTERVAL_MS = 10 * 60 * 1000;
let r2CorsLastSyncAt = 0;

// Browser media uploads happen before the final post/profile mutation. The
// mutation still enforces account ownership, so a temporary upload token should
// not fail just because a web session's auth subject and active account id are
// out of sync.
const WEB_MEDIA_UPLOAD_ROOTS = new Set([
  "avatars",
  "music",
  "podcasts",
  "posts",
  "profiles",
  "tmp",
]);

const ALLOWED_CONTENT_TYPES: AllowedMediaType[] = [
  { contentType: "image/jpeg", maxBytes: 25 * 1024 * 1024 },
  { contentType: "image/png", maxBytes: 25 * 1024 * 1024 },
  { contentType: "image/webp", maxBytes: 25 * 1024 * 1024 },
  { contentType: "image/heic", maxBytes: 25 * 1024 * 1024 },
  { contentType: "image/heif", maxBytes: 25 * 1024 * 1024 },
  { contentType: "audio/mp4", maxBytes: 200 * 1024 * 1024 },
  { contentType: "audio/x-m4a", maxBytes: 200 * 1024 * 1024 },
  { contentType: "audio/m4a", maxBytes: 200 * 1024 * 1024 },
  { contentType: "audio/mpeg", maxBytes: 200 * 1024 * 1024 },
  { contentType: "audio/aac", maxBytes: 200 * 1024 * 1024 },
  { contentType: "video/mp4", maxBytes: 500 * 1024 * 1024 },
  { contentType: "video/quicktime", maxBytes: 500 * 1024 * 1024 },
];

Deno.serve((req) => withRequestLogging(req, async (log) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const authed = await currentUserId(req);
    setLogAuthUser(log, authed);
    if (!authed) return unauthorized();
    setLogAccountScope(log, authed);

    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const last = parts[parts.length - 1] ?? "";

    if (req.method === "POST" && last === "upload-token") {
      return await issueUploadToken(req, authed);
    }

    return notFound();
  } catch (error) {
    return serverError(error);
  }
}));

async function issueUploadToken(req: Request, authed: string): Promise<Response> {
  const payload = await req.json().catch(() => null);
  if (!payload || typeof payload !== "object") {
    return badRequest("Invalid request body.");
  }

  const accountID = readEnv("CLOUDFLARE_R2_ACCOUNT_ID");
  const accessKeyID = readEnv("CLOUDFLARE_R2_ACCESS_KEY_ID");
  const secretAccessKey = readEnv("CLOUDFLARE_R2_SECRET_ACCESS_KEY");
  const configuredBucket = readEnv("CLOUDFLARE_R2_BUCKET") ?? "scrolls-media";
  const cdnBaseURL = normalizeBaseURL(readEnv("CLOUDFLARE_R2_CDN_BASE_URL"));

  if (!accountID || !accessKeyID || !secretAccessKey || !configuredBucket || !cdnBaseURL) {
    return badRequest("R2 upload is not configured.");
  }

  const contentType = normalizeText(payload.contentType)?.toLowerCase() ?? "";
  const allow = ALLOWED_CONTENT_TYPES.find((entry) => entry.contentType === contentType);
  if (!allow) {
    return badRequest("Unsupported contentType.");
  }

  const requestedMaxBytes = Number(payload.maxBytes ?? allow.maxBytes);
  if (!Number.isFinite(requestedMaxBytes) || requestedMaxBytes <= 0) {
    return badRequest("Invalid maxBytes.");
  }
  if (requestedMaxBytes > allow.maxBytes) {
    return badRequest(`maxBytes exceeds allowed limit for ${contentType}.`);
  }

  const requestedTTL = Number(payload.expiresInSeconds ?? DEFAULT_URL_TTL_SECONDS);
  const expiresInSeconds = Number.isFinite(requestedTTL)
    ? Math.max(30, Math.min(MAX_URL_TTL_SECONDS, Math.floor(requestedTTL)))
    : DEFAULT_URL_TTL_SECONDS;

  const objectKey = normalizeObjectKey(payload.objectKey);
  if (!objectKey) return badRequest("objectKey is required.");

  const ownerID = extractOwnerIDFromObjectKey(objectKey);
  if (!ownerID) return badRequest("objectKey must identify an owner account.");

  const requestedAuthorID = normalizeText(payload.authorID)?.toLowerCase() ?? "";
  if (requestedAuthorID && ownerID !== requestedAuthorID) {
    return unauthorized("objectKey owner does not match authorID.");
  }

  const canWriteForOwner = await canActAsAccount(authed, ownerID);
  if (!canWriteForOwner) {
    const root = objectKeyRoot(objectKey);
    if (!WEB_MEDIA_UPLOAD_ROOTS.has(root)) {
      return unauthorized();
    }

    console.warn(JSON.stringify({
      event: "upload_token_scope_fallback",
      authed,
      ownerID,
      root,
      objectKey,
    }));
  }

  const requestedBucket = normalizeText(payload.bucket) ?? configuredBucket;
  if (requestedBucket !== configuredBucket) {
    return badRequest("Unsupported bucket.");
  }

  await syncR2CorsPolicy({
    accountID,
    accessKeyID,
    secretAccessKey,
    bucket: configuredBucket,
  });

  const uploadURL = await createR2PresignedUploadURL({
    accountID,
    accessKeyID,
    secretAccessKey,
    bucket: configuredBucket,
    objectKey,
    contentType,
    expiresInSeconds,
  });

  const nonce = crypto.randomUUID();
  const publicURL = `${cdnBaseURL}/${encodeObjectKeyForURL(objectKey)}`;
  const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();

  return json({
    provider: "r2",
    bucket: configuredBucket,
    objectKey,
    contentType,
    maxBytes: Math.floor(requestedMaxBytes),
    uploadURL,
    publicURL,
    expiresInSeconds,
    expiresAt,
    nonce,
    requiredHeaders: {
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
}

async function syncR2CorsPolicy(input: {
  accountID: string;
  accessKeyID: string;
  secretAccessKey: string;
  bucket: string;
}) {
  const now = Date.now();
  if (now - r2CorsLastSyncAt < R2_CORS_SYNC_INTERVAL_MS) return;
  try {
    await ensureR2BucketCors({
      ...input,
      allowedOrigins: R2_WEB_UPLOAD_ALLOWED_ORIGINS,
    });
    r2CorsLastSyncAt = now;
    console.log(JSON.stringify({
      event: "r2_cors_sync_complete",
      bucket: input.bucket,
      origins: R2_WEB_UPLOAD_ALLOWED_ORIGINS,
    }));
  } catch (error) {
    console.warn(JSON.stringify({
      event: "r2_cors_sync_failed",
      bucket: input.bucket,
      origins: R2_WEB_UPLOAD_ALLOWED_ORIGINS,
      error: error instanceof Error ? error.message : String(error),
    }));
  }
}

function normalizeText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeObjectKey(value: unknown): string | null {
  const raw = normalizeText(value);
  if (!raw) return null;

  const normalized = raw
    .replace(/\\/g, "/")
    .replace(/^\/+/, "")
    .replace(/\/+/g, "/");

  if (!normalized || normalized.includes("..") || normalized.includes("//")) {
    return null;
  }

  const segments = normalized.split("/").filter(Boolean);
  if (segments.length < 3) return null;
  return segments.join("/");
}

function extractOwnerIDFromObjectKey(objectKey: string): string {
  const segments = objectKey.split("/").filter(Boolean);
  if (segments.length < 2) return "";

  const root = segments[0]?.trim().toLowerCase() ?? "";
  if (["posts", "podcasts", "music", "moments", "avatars", "profiles", "tmp", "circle-voice", "circles-audio", "circles-photos"].includes(root)) {
    return segments[1]?.trim().toLowerCase() ?? "";
  }
  return root;
}

function objectKeyRoot(objectKey: string): string {
  return objectKey.split("/").filter(Boolean)[0]?.trim().toLowerCase() ?? "";
}

function normalizeBaseURL(value: string | null): string | null {
  const normalized = normalizeText(value);
  if (!normalized) return null;
  return normalized.replace(/\/+$/, "");
}

function encodeObjectKeyForURL(objectKey: string): string {
  return objectKey.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}

function readEnv(name: string): string | null {
  const value = Deno.env.get(name);
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
