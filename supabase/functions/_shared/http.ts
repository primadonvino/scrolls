import { createClient } from "npm:@supabase/supabase-js@2";

// Prefer Supabase runtime-provided vars first so edge auth always targets the
// active deployed project. SCROLLS_* are only fallback overrides for local/dev.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? Deno.env.get("SCROLLS_SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SCROLLS_SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SCROLLS_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FOUNDER_USER_IDS = parseFounderUserIDs();

export type AppUser = {
  id: string;
  username: string;
  displayName: string;
  display_name?: string;
  bio: string;
  isVerified: boolean;
  is_verified?: boolean;
  isFounder: boolean;
  is_founder?: boolean;
  isPrivate: boolean;
  is_private?: boolean;
  accountType?: string | null;
  account_type?: string | null;
  websiteURL?: string | null;
  website_url?: string | null;
  venmoURL?: string | null;
  venmo_url?: string | null;
  cashAppURL?: string | null;
  cashapp_url?: string | null;
  businessLocation?: string | null;
  business_location?: string | null;
  businessPhone?: string | null;
  business_phone?: string | null;
  homeCity?: string | null;
  home_city?: string | null;
  avatarRef?: string | null;
  avatar_ref?: string | null;
  avatarProvider?: string | null;
  avatar_provider?: string | null;
  avatarBucket?: string | null;
  avatar_bucket?: string | null;
  avatarObjectKey?: string | null;
  avatar_object_key?: string | null;
  signatureRef?: string | null;
  signature_ref?: string | null;
  avatarVideoRef?: string | null;
  avatar_video_ref?: string | null;
  subscriptionPlan?: string | null;
  subscription_plan?: string | null;
  subscriptionExpiresAt?: string | null;
  subscription_expires_at?: string | null;
  pinnedPostID?: string | null;
  pinned_post_id?: string | null;
  dateOfBirth?: string | null;
  date_of_birth?: string | null;
  ageAssuranceCompletedAt?: string | null;
  age_assurance_completed_at?: string | null;
  parentalControls?: Record<string, unknown> | null;
  parental_controls?: Record<string, unknown> | null;
  writeVersion?: string | null;
  updated_at?: string | null;
};

export const SUMMARY_USER_COLUMNS =
  "id, username, display_name, is_verified, is_founder, is_private, account_type, home_city, avatar_ref, avatar_provider, avatar_bucket, avatar_object_key, pinned_post_id, date_of_birth, age_assurance_completed_at, parental_controls, updated_at";

export const SEARCH_USER_COLUMNS =
  "id, username, display_name, bio, is_verified, is_founder, is_private, account_type, home_city, avatar_provider, avatar_bucket, avatar_object_key, pinned_post_id, date_of_birth, age_assurance_completed_at, parental_controls, updated_at";

export const FULL_USER_COLUMNS =
  "id, username, display_name, bio, is_verified, is_founder, is_private, account_type, website_url, venmo_url, cashapp_url, business_location, business_phone, home_city, avatar_ref, avatar_provider, avatar_bucket, avatar_object_key, signature_ref, avatar_video_ref, subscription_plan, subscription_expires_at, pinned_post_id, date_of_birth, age_assurance_completed_at, parental_controls, updated_at";

export type RequestLogContext = {
  requestID: string;
  route: string;
  authUserID: string | null;
  accountScope: string[] | null;
};

type RequestHandler = (log: RequestLogContext) => Promise<Response> | Response;

export function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  };
}

export function optionsResponse() {
  return new Response("ok", { headers: corsHeaders() });
}

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json",
    },
  });
}

export function notFound() {
  return json({ error: "Not found" }, 404);
}

export function badRequest(message: string) {
  return json({ error: message }, 400);
}

export function unauthorized(message = "Unauthorized") {
  return json({ error: message }, 401);
}

export function serverError(error: unknown) {
  const message = error instanceof Error ? error.message : "Internal error";
  return json({ error: message }, 500);
}

export async function withRequestLogging(req: Request, handler: RequestHandler): Promise<Response> {
  const startedAt = Date.now();
  const url = new URL(req.url);
  const context: RequestLogContext = {
    requestID: (req.headers.get("x-request-id") ?? "").trim() || crypto.randomUUID(),
    route: url.pathname || "/",
    authUserID: null,
    accountScope: null,
  };

  try {
    const response = await handler(context);
    logRequest(req.method, context, response.status, Date.now() - startedAt);
    return response;
  } catch (error) {
    const response = serverError(error);
    logRequest(req.method, context, response.status, Date.now() - startedAt, error);
    return response;
  }
}

export function setLogAuthUser(context: RequestLogContext, userID: string | null | undefined) {
  const normalized = String(userID ?? "").trim().toLowerCase();
  context.authUserID = normalized.length > 0 ? normalized : null;
}

export function setLogAccountScope(
  context: RequestLogContext,
  scope: string | string[] | null | undefined,
) {
  const values = Array.isArray(scope) ? scope : [scope ?? ""];
  const normalized = Array.from(
    new Set(
      values
        .map((value) => String(value).trim().toLowerCase())
        .filter((value) => value.length > 0),
    ),
  );
  context.accountScope = normalized.length > 0 ? normalized : null;
}

export function requireEnv() {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("Missing Supabase environment variables.");
  }
}

export function serviceClient() {
  requireEnv();
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export function isFounderUserID(userID: string): boolean {
  const normalized = String(userID).trim().toLowerCase();
  return normalized.length > 0 && FOUNDER_USER_IDS.has(normalized);
}

export function founderUserIDs(): string[] {
  return Array.from(FOUNDER_USER_IDS);
}

export async function currentUserId(req: Request): Promise<string | null> {
  requireEnv();
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;

  // Verify the bearer token against Auth using service role context to avoid
  // anon-key/environment mismatches causing false "Invalid JWT" rejections.
  const admin = serviceClient();
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) {
    console.warn(JSON.stringify({
      event: "edge_auth_get_user_failed",
      reason: error?.message ?? "missing_user",
      has_authorization_header: authHeader.length > 0,
      token_chars: token.length,
    }));
    return null;
  }
  return data.user.id;
}

export function mapUser(row: Record<string, unknown>): AppUser {
  const expiresRaw = row.subscription_expires_at;
  const dateOfBirthRaw = row.date_of_birth;
  const ageAssuranceRaw = row.age_assurance_completed_at;
  const updatedRaw = row.updated_at;
  const displayName = String(row.display_name ?? "");
  const isVerified = Boolean(row.is_verified ?? false);
  const isFounder = Boolean(row.is_founder ?? false);
  const isPrivate = Boolean(row.is_private ?? false);
  const accountType = (row.account_type as string | null) ?? "personal";
  const websiteURL = (row.website_url as string | null) ?? null;
  const venmoURL = (row.venmo_url as string | null) ?? null;
  const cashAppURL = (row.cashapp_url as string | null) ?? null;
  const businessLocation = (row.business_location as string | null) ?? null;
  const businessPhone = (row.business_phone as string | null) ?? null;
  const homeCity = (row.home_city as string | null) ?? null;
  const avatarRef = (row.avatar_ref as string | null) ?? null;
  const avatarProvider = (row.avatar_provider as string | null) ?? null;
  const avatarBucket = (row.avatar_bucket as string | null) ?? null;
  const avatarObjectKey = (row.avatar_object_key as string | null) ?? null;
  const signatureRef = (row.signature_ref as string | null) ?? null;
  const avatarVideoRef = (row.avatar_video_ref as string | null) ?? null;
  const subscriptionPlan = (row.subscription_plan as string | null) ?? null;
  const subscriptionExpiresAt = typeof expiresRaw === "string" ? new Date(expiresRaw).toISOString() : null;
  const pinnedPostID = (row.pinned_post_id as string | null) ?? null;
  const dateOfBirth = typeof dateOfBirthRaw === "string" ? dateOfBirthRaw : null;
  const ageAssuranceCompletedAt = typeof ageAssuranceRaw === "string" ? new Date(ageAssuranceRaw).toISOString() : null;
  const parentalControls = isRecord(row.parental_controls) ? row.parental_controls : null;
  const writeVersion = typeof updatedRaw === "string" ? new Date(updatedRaw).toISOString() : null;
  return {
    id: String(row.id ?? ""),
    username: String(row.username ?? ""),
    displayName,
    display_name: displayName,
    bio: String(row.bio ?? ""),
    isVerified,
    is_verified: isVerified,
    isFounder,
    is_founder: isFounder,
    isPrivate,
    is_private: isPrivate,
    accountType,
    account_type: accountType,
    websiteURL,
    website_url: websiteURL,
    venmoURL,
    venmo_url: venmoURL,
    cashAppURL,
    cashapp_url: cashAppURL,
    businessLocation,
    business_location: businessLocation,
    businessPhone,
    business_phone: businessPhone,
    homeCity,
    home_city: homeCity,
    avatarRef,
    avatar_ref: avatarRef,
    avatarProvider,
    avatar_provider: avatarProvider,
    avatarBucket,
    avatar_bucket: avatarBucket,
    avatarObjectKey,
    avatar_object_key: avatarObjectKey,
    signatureRef,
    signature_ref: signatureRef,
    avatarVideoRef,
    avatar_video_ref: avatarVideoRef,
    subscriptionPlan,
    subscription_plan: subscriptionPlan,
    subscriptionExpiresAt,
    subscription_expires_at: subscriptionExpiresAt,
    pinnedPostID,
    pinned_post_id: pinnedPostID,
    dateOfBirth,
    date_of_birth: dateOfBirth,
    ageAssuranceCompletedAt,
    age_assurance_completed_at: ageAssuranceCompletedAt,
    parentalControls,
    parental_controls: parentalControls,
    writeVersion,
    updated_at: writeVersion,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseFounderUserIDs(): Set<string> {
  const configured = Deno.env.get("SCROLLS_FOUNDER_USER_IDS") ?? "";
  const values = configured
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter((value) => value.length > 0);
  if (values.length > 0) return new Set(values);
  // Default founder identity for local/dev compatibility until SCROLLS_FOUNDER_USER_IDS is configured.
  return new Set([
    "cbc29d93-94c3-4cb8-9f22-cfc53d60c330",
    "283dbe7a-fc81-46ce-91c8-297f75bfd6d1",
  ]);
}

function logRequest(
  method: string,
  context: RequestLogContext,
  status: number,
  latencyMS: number,
  error?: unknown,
) {
  const payload: Record<string, unknown> = {
    event: "edge_request",
    request_id: context.requestID,
    method,
    route: context.route,
    status,
    latency_ms: latencyMS,
    auth_user_id: context.authUserID,
    account_scope: context.accountScope,
  };
  if (error) {
    payload.error = error instanceof Error ? error.message : String(error);
  }
  console.log(JSON.stringify(payload));
}
