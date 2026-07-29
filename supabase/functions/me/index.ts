import {
  badRequest,
  currentUserId,
  json,
  mapUser,
  notFound,
  optionsResponse,
  serverError,
  setLogAccountScope,
  setLogAuthUser,
  serviceClient,
  SUMMARY_USER_COLUMNS,
  unauthorized,
  withRequestLogging,
} from "../_shared/http.ts";
import { resolveAccountScopeForUser, resolveScopedAccountID } from "../_shared/account_scope.ts";
import { fetchUsersByIds, mapPost } from "../_shared/mappers.ts";
import { isValidSafetyReportReason, normalizeReportNotes, normalizeReportReason } from "../_shared/safety.ts";

Deno.serve((req) => withRequestLogging(req, async (log) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const authed = await currentUserId(req);
    setLogAuthUser(log, authed);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const route = parts[parts.length - 1] ?? "";

    if (!authed) {
      // Public read fallback: following/followers are intentionally public graph data.
      // This keeps directory/search usable if a client session token is temporarily missing.
      const requestedRaw = (url.searchParams.get("user_id") ?? "").trim().toLowerCase();
      if ((route === "following" || route === "followers") && req.method === "GET" && requestedRaw.length > 0) {
        setLogAccountScope(log, `public:${requestedRaw}`);
        if (route === "following") return await following(requestedRaw);
        return await followers(requestedRaw);
      }
      return unauthorized();
    }

    const effectiveUserID = await resolveEffectiveUserID(req, authed, route);
    if (!effectiveUserID) return unauthorized();
    setLogAccountScope(log, effectiveUserID);

    if (route === "following" && req.method === "GET") return await following(effectiveUserID);
    if (route === "followers" && req.method === "GET") return await followers(effectiveUserID);
    if (route === "follow-requests" && req.method === "GET") return await followRequests(effectiveUserID);
    if (route === "notifications" && req.method === "GET") return await notifications(req, effectiveUserID);
    if (route === "device-token" && req.method === "POST") return await registerDeviceToken(req, effectiveUserID);
    if (route === "device-token" && req.method === "DELETE") return await unregisterDeviceToken(req, effectiveUserID);
    if (route === "tombstones" && req.method === "GET") return await tombstones(req);
    if (route === "mark" && req.method === "POST") return await markNotification(req, effectiveUserID);
    if (route === "read-all" && req.method === "POST") return await markReadAll(effectiveUserID);
    if (route === "read" && req.method === "DELETE") return await deleteRead(effectiveUserID);
    if (route === "circles" && req.method === "GET") {
      const since = url.searchParams.get("since")?.trim() || null;
      return await circles(effectiveUserID, since);
    }
    if (route === "blocks" && req.method === "GET") return await listBlocks(effectiveUserID);
    if (route === "block" && req.method === "POST") return await blockUser(req, effectiveUserID);
    if (route === "block" && req.method === "DELETE") return await unblockUser(req, effectiveUserID);
    if (route === "content-report" && req.method === "POST") return await reportContent(req, effectiveUserID);
    if (route === "content-reports" && req.method === "GET") return await listContentReports(req, effectiveUserID);
    if (route === "review" && req.method === "PATCH" && parts.includes("content-reports")) {
      const reportID = parts[parts.length - 2] ?? "";
      return await reviewContentReport(req, effectiveUserID, reportID);
    }
    return notFound();
  } catch (error) {
    return serverError(error);
  }
}));

const NOTIFICATION_RETENTION_DAYS = 14;
const CIRCLE_VOICE_PAYLOAD_PREFIX = "[CIRCLE_VOICE_BASE64]";
const CIRCLE_PHOTO_PAYLOAD_PREFIX = "[CIRCLE_PHOTO]";
const CIRCLE_MEDIA_RETENTION_MS = 24 * 60 * 60 * 1000;
const FOUNDER_CANONICAL_ACCOUNT_ID = "cbc29d93-94c3-4cb8-9f22-cfc53d60c330";
const FOUNDER_MANAGED_ACCOUNT_IDS = new Set([
  "4b80ea39-95a4-4389-a55a-6a042294d82f",
  "22b5cf34-2285-4e72-b1e8-8fa95a25d3c0",
  "ed2e1318-d186-4cc9-b4e9-7e43c5b87a8d",
  "db4251ba-e3d4-4489-a51a-37e2e5a71fcc",
  "aec0dcd5-2046-4753-9244-0b5293834e11",
]);
const FOUNDER_AUTH_ALIAS_IDS = new Set([
  "cbc29d93-94c3-4cb8-9f22-cfc53d60c330",
  "283dbe7a-fc81-46ce-91c8-297f75bfd6d1",
  "cb6f0aa1-2a39-4ede-90b0-af5a63da5a5d",
]);
const PROTECTED_FOUNDER_BLOCK_IDS = new Set([
  FOUNDER_CANONICAL_ACCOUNT_ID,
  ...FOUNDER_MANAGED_ACCOUNT_IDS,
  ...FOUNDER_AUTH_ALIAS_IDS,
]);

function isProtectedFounderBlockTarget(userID: string): boolean {
  return PROTECTED_FOUNDER_BLOCK_IDS.has(String(userID).trim().toLowerCase());
}

async function purgeExpiredNotifications(admin: ReturnType<typeof serviceClient>) {
  const cutoffISO = new Date(Date.now() - (NOTIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000)).toISOString();
  await admin.from("notifications").delete().lt("created_at", cutoffISO);
}

async function resolveEffectiveUserID(req: Request, authed: string, route: string): Promise<string | null> {
  const requestedRaw = new URL(req.url).searchParams.get("user_id");
  const normalizedAuthed = String(authed).trim().toLowerCase();
  // These routes must always resolve to a specific account — never cluster scope.
  if (
    route === "notifications" || route === "read-all" || route === "read" ||
    route === "device-token" || route === "blocks" || route === "block"
  ) {
    if (!requestedRaw || requestedRaw.trim().length === 0) return normalizedAuthed;
    return await resolveScopedAccountID(normalizedAuthed, requestedRaw);
  }
  return await resolveScopedAccountID(normalizedAuthed, requestedRaw ?? "");
}

async function following(userID: string) {
  const admin = serviceClient();
  const normalizedUserID = userID.toLowerCase();
  const scope = await resolveAccountScopeForUser(normalizedUserID);
  const clusterIDs = Array.from(scope?.accountIDs ?? [normalizedUserID]);
  const rel = clusterIDs.length == 1
    ? await admin.from("follows").select("followee_id").eq("follower_id", clusterIDs[0]).eq("status", "accepted")
    : await admin.from("follows").select("followee_id").in("follower_id", clusterIDs).eq("status", "accepted");
  if (rel.error) return json([], 200);
  const ids = new Set((rel.data ?? []).map((row) => String(row.followee_id)));
  for (const accountID of clusterIDs) {
    if (accountID !== normalizedUserID) {
      ids.add(accountID);
    }
  }
  const resolvedIDs = Array.from(ids);
  if (resolvedIDs.length === 0) return json([]);
  const users = await admin.from("account_profiles").select(SUMMARY_USER_COLUMNS).in("id", resolvedIDs);
  if (users.error) return json([]);
  return json((users.data ?? []).map((row) => mapUser(row as Record<string, unknown>)));
}

async function followers(userID: string) {
  const admin = serviceClient();
  const rel = await admin.from("follows")
    .select("follower_id")
    .eq("followee_id", userID)
    .eq("status", "accepted");
  if (rel.error) return json([], 200);
  const ids = (rel.data ?? []).map((row) => row.follower_id);
  if (ids.length === 0) return json([]);
  const users = await admin.from("account_profiles").select(SUMMARY_USER_COLUMNS).in("id", ids);
  if (users.error) return json([]);
  return json((users.data ?? []).map((row) => mapUser(row as Record<string, unknown>)));
}

async function followRequests(userID: string) {
  const admin = serviceClient();
  const rel = await admin.from("follows")
    .select("follower_id")
    .eq("followee_id", userID)
    .eq("status", "pending");
  if (rel.error) return json([], 200);
  const ids = (rel.data ?? []).map((row) => row.follower_id);
  if (ids.length === 0) return json([]);
  const users = await admin.from("account_profiles").select(SUMMARY_USER_COLUMNS).in("id", ids);
  if (users.error) return json([]);
  return json((users.data ?? []).map((row) => mapUser(row as Record<string, unknown>)));
}

async function notifications(req: Request, userID: string) {
  const admin = serviceClient();
  await purgeExpiredNotifications(admin);
  const cutoffISO = new Date(Date.now() - (NOTIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000)).toISOString();
  const url = new URL(req.url);
  const limit = Math.max(1, Math.min(200, Number(url.searchParams.get("limit") ?? "60")));
  const beforeRaw = (url.searchParams.get("before") ?? "").trim();
  const beforeDate = beforeRaw ? new Date(beforeRaw) : null;

  let query = admin.from("notifications")
    .select("*")
    .eq("user_id", userID)
    .gte("created_at", cutoffISO)
    .order("created_at", { ascending: false })
    .limit(limit + 1);
  if (beforeDate && !Number.isNaN(beforeDate.getTime())) {
    query = query.lt("created_at", beforeDate.toISOString());
  }
  const rows = await query;
  if (rows.error) return json({ items: [], nextCursor: null });
  const raw = rows.data ?? [];
  const hasMore = raw.length > limit;
  const trimmed = hasMore ? raw.slice(0, limit) : raw;
  const payload = trimmed.map((row) => ({
    id: row.id,
    userID: row.user_id,
    type: row.type,
    title: row.title,
    message: row.message,
    actorID: row.actor_id ?? null,
    objectID: row.object_id ?? null,
    createdAt: new Date(row.created_at).toISOString(),
    isRead: Boolean(row.is_read),
  }));
  const nextCursor = hasMore ? String(trimmed[trimmed.length - 1]?.created_at ?? "") : null;
  return json({ items: payload, nextCursor });
}

async function tombstones(req: Request) {
  const url = new URL(req.url);
  const ids = Array.from(new Set(
    (url.searchParams.get("post_ids") ?? "")
      .split(",")
      .map((value) => value.trim().toLowerCase())
      .filter((value) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)),
  )).slice(0, 200);
  if (ids.length === 0) return json({ deletedPostIDs: [] });

  const admin = serviceClient();
  const deleted = await admin.from("deleted_post_tombstones")
    .select("post_id")
    .in("post_id", ids);
  if (deleted.error) return json({ deletedPostIDs: [] });
  const deletedPostIDs = Array.from(new Set(
    (deleted.data ?? [])
      .map((row) => String(row.post_id ?? "").trim().toLowerCase())
      .filter(Boolean),
  ));
  return json({ deletedPostIDs });
}

async function registerDeviceToken(req: Request, userID: string) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const token = String(payload.token ?? "").trim().toLowerCase();
  const platform = String(payload.platform ?? "ios").trim().toLowerCase() || "ios";
  const environment = String(payload.environment ?? "production").trim().toLowerCase() || "production";
  const localeIdentifier = String(payload.locale_identifier ?? payload.localeIdentifier ?? "").trim() || null;
  const appVersion = String(payload.app_version ?? payload.appVersion ?? "").trim() || null;

  if (token.length < 32) return badRequest("Push token is required.");

  const admin = serviceClient();
  const nowISO = new Date().toISOString();
  const upsert = await admin.from("device_tokens").upsert({
    user_id: userID,
    token,
    platform,
    environment,
    locale_identifier: localeIdentifier,
    app_version: appVersion,
    is_active: true,
    last_seen_at: nowISO,
    updated_at: nowISO,
  }, {
    onConflict: "token,environment",
  });
  if (upsert.error) return badRequest(upsert.error.message);
  return json({ ok: true });
}

async function unregisterDeviceToken(req: Request, userID: string) {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const token = String(payload.token ?? "").trim().toLowerCase();
  if (token.length < 32) return badRequest("Push token is required.");

  const admin = serviceClient();
  const update = await admin.from("device_tokens")
    .update({
      is_active: false,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userID)
    .eq("token", token);
  if (update.error) return badRequest(update.error.message);
  return json({ ok: true });
}

async function markNotification(req: Request, userID: string) {
  const admin = serviceClient();
  await purgeExpiredNotifications(admin);
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const notificationID = String(payload.id ?? payload.notification_id ?? "").trim();
  if (!notificationID) return badRequest("Notification id is required.");
  const read = Boolean(payload.is_read ?? payload.isRead ?? true);
  const result = await admin.from("notifications")
    .update({ is_read: read })
    .eq("user_id", userID)
    .eq("id", notificationID);
  if (result.error) return badRequest(result.error.message);
  return json({ ok: true, id: notificationID, isRead: read });
}

async function markReadAll(userID: string) {
  const admin = serviceClient();
  await purgeExpiredNotifications(admin);
  await admin.from("notifications").update({ is_read: true }).eq("user_id", userID);
  return json({ ok: true });
}

async function deleteRead(userID: string) {
  const admin = serviceClient();
  await purgeExpiredNotifications(admin);
  await admin.from("notifications").delete().eq("user_id", userID).eq("is_read", true);
  return json({ ok: true });
}

async function circles(userID: string, since: string | null) {
  // Cross-app safety: ignore the legacy global `since` cursor for now.
  // Scrolls and standalone Circles can write messages into different threads;
  // one global latest-message timestamp can hide older-but-unseen messages in
  // another circle. Return the canonical full inbox until per-circle cursors
  // exist.
  const sinceDate: Date | null = null;

  const admin = serviceClient();
  const memberships = await admin.from("circle_members")
    .select("circle_id")
    .eq("user_id", userID)
    .in("status", ["member", "active", "invited", "pending"]);
  if (memberships.error) return json([]);
  const circleIDs = (memberships.data ?? []).map((row) => row.circle_id);
  if (circleIDs.length === 0) return json([]);

  // Always fetch circle metadata + member roster — these are small and change
  // infrequently.  Clients may omit `since` for full cross-app reconciliation.
  let messageQuery = admin.from("circle_messages")
    .select("*")
    .in("circle_id", circleIDs)
    .is("deleted_at", null)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .order("created_at", { ascending: true });
  if (sinceDate) {
    messageQuery = messageQuery.gt("created_at", sinceDate.toISOString());
  }

  const [circleRows, memberRows, messageRows] = await Promise.all([
    admin.from("circles").select("*").in("id", circleIDs).is("deleted_at", null),
    admin.from("circle_members").select("*").in("circle_id", circleIDs),
    messageQuery,
  ]);
  if (messageRows.error) return badRequest(messageRows.error.message);
  const activeMessageRows = ((messageRows.data ?? []) as Record<string, unknown>[])
    .filter((row) => !isExpiredCircleMediaMessage(row));

  const participantIDs = Array.from(new Set([
    ...((memberRows.data ?? []).map((row) => String(row.user_id ?? "")).filter((value) => value.length > 0)),
    ...(activeMessageRows.map((row) => String(row.user_id ?? "")).filter((value) => value.length > 0)),
  ]));
  // Read member/sender profiles from account_profiles (the same source
  // following/followers use) so avatars resolve. The raw `users` table's
  // avatar columns can be stale/empty for accounts whose avatar lives in
  // account_profiles, which made circle rows fall back to initials.
  const userRows = participantIDs.length > 0
    ? await admin.from("account_profiles").select(SUMMARY_USER_COLUMNS).in("id", participantIDs)
    : { data: [], error: null };

  const userMap: Record<string, ReturnType<typeof mapUser>> = {};
  for (const row of (userRows.data ?? [])) {
    const u = mapUser(row as Record<string, unknown>);
    userMap[u.id] = u;
  }

  const sharedPostIDs = Array.from(new Set(
    activeMessageRows
      .map((row) => String(row.shared_post_id ?? "").trim().toLowerCase())
      .filter((value) => value.length > 0),
  ));
  const sharedPostRows = sharedPostIDs.length > 0
    ? await admin.from("posts").select("*").in("id", sharedPostIDs).is("deleted_at", null)
    : { data: [], error: null };
  if (sharedPostRows.error) return badRequest(sharedPostRows.error.message);
  const sharedAuthorIDs = Array.from(new Set(
    ((sharedPostRows.data ?? []) as Record<string, unknown>[])
      .map((row) => String(row.author_id ?? "").trim().toLowerCase())
      .filter((value) => value.length > 0),
  ));
  const sharedAuthors = await fetchUsersByIds(sharedAuthorIDs);
  const sharedPostMap: Record<string, ReturnType<typeof mapPost>> = {};
  for (const row of ((sharedPostRows.data ?? []) as Record<string, unknown>[])) {
    const postID = String(row.id ?? "").trim().toLowerCase();
    const authorID = String(row.author_id ?? "").trim().toLowerCase();
    const author = sharedAuthors[authorID];
    if (!postID || !author) continue;
    sharedPostMap[postID] = mapPost(row, author);
  }

  const membersByCircle: Record<string, unknown[]> = {};
  for (const row of (memberRows.data ?? [])) {
    const key = String(row.circle_id);
    membersByCircle[key] = membersByCircle[key] ?? [];
    membersByCircle[key].push(row);
  }

  const messagesByCircle: Record<string, unknown[]> = {};
  for (const row of activeMessageRows) {
    const key = String(row.circle_id);
    messagesByCircle[key] = messagesByCircle[key] ?? [];
    messagesByCircle[key].push(row);
  }

  const payload = (circleRows.data ?? []).map((circle) => {
    const id = String(circle.id);
    const members = (membersByCircle[id] ?? []).map((memberRow) => {
      const row = memberRow as Record<string, unknown>;
      return {
        id: String(row.id),
        user: userMap[String(row.user_id)],
        status: String(row.status ?? "invited"),
      };
    }).filter((item) => item.user);
    const messages = (messagesByCircle[id] ?? []).map((messageRow) => {
      const row = messageRow as Record<string, unknown>;
      return {
        id: String(row.id),
        user: userMap[String(row.user_id)],
        encryptedText: String(row.encrypted_text ?? ""),
        encrypted_text: String(row.encrypted_text ?? ""),
        createdAt: new Date(String(row.created_at)).toISOString(),
        created_at: new Date(String(row.created_at)).toISOString(),
        sharedPostID: row.shared_post_id ? String(row.shared_post_id) : null,
        shared_post_id: row.shared_post_id ? String(row.shared_post_id) : null,
        sharedPost: row.shared_post_id ? (sharedPostMap[String(row.shared_post_id).trim().toLowerCase()] ?? null) : null,
        voiceProvider: row.voice_provider ? String(row.voice_provider) : null,
        voice_provider: row.voice_provider ? String(row.voice_provider) : null,
        voiceBucket: row.voice_bucket ? String(row.voice_bucket) : null,
        voice_bucket: row.voice_bucket ? String(row.voice_bucket) : null,
        voiceObjectKey: row.voice_object_key ? String(row.voice_object_key) : null,
        voice_object_key: row.voice_object_key ? String(row.voice_object_key) : null,
        voiceDurationSeconds: row.voice_duration_seconds == null ? null : Number(row.voice_duration_seconds),
        voice_duration_seconds: row.voice_duration_seconds == null ? null : Number(row.voice_duration_seconds),
        photoProvider: row.photo_provider ? String(row.photo_provider) : null,
        photo_provider: row.photo_provider ? String(row.photo_provider) : null,
        photoBucket: row.photo_bucket ? String(row.photo_bucket) : null,
        photo_bucket: row.photo_bucket ? String(row.photo_bucket) : null,
        photoObjectKey: row.photo_object_key ? String(row.photo_object_key) : null,
        photo_object_key: row.photo_object_key ? String(row.photo_object_key) : null,
        photoContentType: row.photo_content_type ? String(row.photo_content_type) : null,
        photo_content_type: row.photo_content_type ? String(row.photo_content_type) : null,
        photoWidth: row.photo_width == null ? null : Number(row.photo_width),
        photo_width: row.photo_width == null ? null : Number(row.photo_width),
        photoHeight: row.photo_height == null ? null : Number(row.photo_height),
        photo_height: row.photo_height == null ? null : Number(row.photo_height),
        expiresAt: row.expires_at ? new Date(String(row.expires_at)).toISOString() : null,
        expires_at: row.expires_at ? new Date(String(row.expires_at)).toISOString() : null,
      };
    }).filter((item) => item.user);
    return {
      id,
      name: String(circle.name ?? ""),
      avatarRef: circle.avatar_ref ? String(circle.avatar_ref) : null,
      avatar_ref: circle.avatar_ref ? String(circle.avatar_ref) : null,
      members,
      messages,
      createdAt: new Date(circle.created_at).toISOString(),
      created_at: new Date(circle.created_at).toISOString(),
    };
  });
  return json(payload);
}

function isExpiredCircleMediaMessage(row: Record<string, unknown>): boolean {
  const hasStructuredVoice = typeof row.voice_object_key === "string" && row.voice_object_key.trim().length > 0;
  const hasStructuredPhoto = typeof row.photo_object_key === "string" && row.photo_object_key.trim().length > 0;
  const encryptedText = String(row.encrypted_text ?? "");
  const hasFallbackVoice = encryptedText.startsWith(`plain:${CIRCLE_VOICE_PAYLOAD_PREFIX}`)
    || encryptedText.startsWith(CIRCLE_VOICE_PAYLOAD_PREFIX);
  const hasFallbackPhoto = encryptedText.startsWith(`plain:${CIRCLE_PHOTO_PAYLOAD_PREFIX}`)
    || encryptedText.startsWith(CIRCLE_PHOTO_PAYLOAD_PREFIX);
  if (!hasStructuredVoice && !hasStructuredPhoto && !hasFallbackVoice && !hasFallbackPhoto) return false;

  const expiresRaw = typeof row.expires_at === "string" ? row.expires_at.trim() : "";
  if (expiresRaw.length > 0) {
    const expiresAt = new Date(expiresRaw);
    if (!Number.isNaN(expiresAt.getTime())) {
      return expiresAt <= new Date();
    }
  }

  const createdAt = new Date(String(row.created_at ?? ""));
  if (Number.isNaN(createdAt.getTime())) return true;
  return createdAt.getTime() + CIRCLE_MEDIA_RETENTION_MS <= Date.now();
}

// ── Block / Unblock ────────────────────────────────────────────────────────

async function listBlocks(blockerID: string): Promise<Response> {
  const admin = serviceClient();
  const result = await admin
    .from("user_blocks")
    .select("blocked_id")
    .eq("blocker_id", blockerID);
  if (result.error) return json({ error: result.error.message }, 500);
  const ids = (result.data ?? [])
    .map((row) => String(row.blocked_id ?? ""))
    .filter((id) => id.length > 0 && !isProtectedFounderBlockTarget(id));
  return json({ blockedUserIDs: ids });
}

async function blockUser(req: Request, blockerID: string): Promise<Response> {
  const payload = await req.json().catch(() => ({}));
  const targetUserID = String(payload.targetUserID ?? payload.target_user_id ?? "").trim().toLowerCase();
  if (!targetUserID) return json({ error: "targetUserID required." }, 400);
  if (targetUserID === blockerID.toLowerCase()) return json({ error: "Cannot block yourself." }, 400);
  if (isProtectedFounderBlockTarget(targetUserID)) {
    return json({ error: "Founder accounts cannot be blocked." }, 403);
  }
  const admin = serviceClient();
  const upsert = await admin.from("user_blocks").upsert({
    blocker_id: blockerID,
    blocked_id: targetUserID,
    created_at: new Date().toISOString(),
  }, { onConflict: "blocker_id,blocked_id" });
  if (upsert.error) return json({ error: upsert.error.message }, 500);
  const report = await admin.from("profile_reports").upsert({
    target_user_id: targetUserID,
    reporter_id: blockerID,
    reason: "harassment_bullying",
    notes: "User blocked this account from an in-app UGC safety control.",
    status: "pending",
    reviewed_by: null,
    reviewed_at: null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "target_user_id,reporter_id" });
  if (report.error) {
    console.warn(JSON.stringify({
      event: "block_profile_report_failed",
      blockerID,
      targetUserID,
      error: report.error.message,
    }));
  }
  return json({ ok: true });
}

async function unblockUser(req: Request, blockerID: string): Promise<Response> {
  const payload = await req.json().catch(() => ({}));
  const targetUserID = String(payload.targetUserID ?? payload.target_user_id ?? "").trim().toLowerCase();
  if (!targetUserID) return json({ error: "targetUserID required." }, 400);
  const admin = serviceClient();
  const remove = await admin.from("user_blocks")
    .delete()
    .eq("blocker_id", blockerID)
    .eq("blocked_id", targetUserID);
  if (remove.error) return json({ error: remove.error.message }, 500);
  return json({ ok: true });
}

// ── Generic UGC content reports ───────────────────────────────────────────
//
// Reports comments, music tracks, voice messages, circle messages, and
// avatar/profile media.  Posts use the existing /posts/{id}/report path;
// profiles use /users/{id}/report; live streams use a dedicated
// live_stream_reports table.  This handler covers everything else.

const VALID_CONTENT_REPORT_TARGET_TYPES = new Set([
  "comment",
  "music_track",
  "voice_message",
  "circle_message",
  "avatar",
  // Circles standalone: reporting a 24-hour moment, and reporting a
  // profile (also filed automatically when a user blocks someone, so the
  // developer is notified of the inappropriate content per Guideline 1.2).
  "circle_moment",
  "profile",
]);

async function reportContent(req: Request, reporterID: string): Promise<Response> {
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const targetType = String(payload.targetType ?? payload.target_type ?? "").trim().toLowerCase();
  const targetID = String(payload.targetID ?? payload.target_id ?? "").trim().toLowerCase();
  const targetOwnerIDRaw = String(payload.targetOwnerID ?? payload.target_owner_id ?? "").trim().toLowerCase();
  const reason = normalizeReportReason(payload.reason);
  const notes = normalizeReportNotes(payload.notes);

  if (!VALID_CONTENT_REPORT_TARGET_TYPES.has(targetType)) {
    return json({ error: "Unsupported target type." }, 400);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(targetID)) {
    return json({ error: "targetID is required." }, 400);
  }
  if (!isValidSafetyReportReason(reason)) {
    return json({ error: "Invalid report reason." }, 400);
  }
  // targetOwnerID is optional (we may not know who owns a comment author
  // ID client-side if the row was redacted) — but if supplied it must
  // pass a basic shape check so the FK doesn't blow up.
  let targetOwnerID: string | null = null;
  if (targetOwnerIDRaw.length > 0) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(targetOwnerIDRaw)) {
      return json({ error: "targetOwnerID must be a UUID." }, 400);
    }
    targetOwnerID = targetOwnerIDRaw;
  }
  if (targetOwnerID && targetOwnerID === reporterID.toLowerCase()) {
    return json({ error: "Cannot report your own content." }, 400);
  }

  const admin = serviceClient();
  const write = await admin.from("content_reports").upsert({
    target_type:     targetType,
    target_id:       targetID,
    target_owner_id: targetOwnerID,
    reporter_id:     reporterID.toLowerCase(),
    reason,
    notes,
    status:          "pending",
    reviewed_by:     null,
    reviewed_at:     null,
    updated_at:      new Date().toISOString(),
  }, { onConflict: "target_type,target_id,reporter_id" });
  if (write.error) return json({ error: write.error.message }, 500);
  return json({ ok: true });
}

// ── Founder/admin: content-report review queue ──────────────────────────────

async function isContentReportReviewer(
  admin: ReturnType<typeof serviceClient>,
  userID: string,
): Promise<boolean> {
  const row = await admin.from("users").select("is_founder, is_admin").eq("id", userID.toLowerCase()).maybeSingle();
  if (row.error || !row.data) return false;
  return Boolean(row.data.is_founder ?? false) || Boolean(row.data.is_admin ?? false);
}

async function listContentReports(req: Request, viewerID: string): Promise<Response> {
  const admin = serviceClient();
  if (!(await isContentReportReviewer(admin, viewerID))) return unauthorized();

  const url = new URL(req.url);
  const status = String(url.searchParams.get("status") ?? "pending").trim().toLowerCase();
  const limit = Math.max(1, Math.min(200, Number(url.searchParams.get("limit") ?? "100")));

  let query = admin.from("content_reports")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (["pending", "confirmed", "dismissed"].includes(status)) {
    query = query.eq("status", status);
  }
  const reports = await query;
  if (reports.error) return json({ error: reports.error.message }, 500);
  const rows = reports.data ?? [];

  const ownerIDs = Array.from(new Set(
    rows.map((row) => String((row as { target_owner_id?: unknown }).target_owner_id ?? ""))
      .filter(Boolean)
  ));
  const reporterIDs = Array.from(new Set(rows.map((row) => String((row as { reporter_id?: unknown }).reporter_id ?? ""))));

  const [owners, reporters] = await Promise.all([
    ownerIDs.length ? fetchUsersByIds(ownerIDs) : Promise.resolve({}),
    reporterIDs.length ? fetchUsersByIds(reporterIDs) : Promise.resolve({}),
  ]);

  const payload = rows.map((row) => {
    const oid = String((row as { target_owner_id?: unknown }).target_owner_id ?? "");
    const rid = String((row as { reporter_id?: unknown }).reporter_id ?? "");
    return {
      id:            String((row as { id?: unknown }).id ?? ""),
      targetType:    String((row as { target_type?: unknown }).target_type ?? ""),
      targetID:      String((row as { target_id?: unknown }).target_id ?? ""),
      targetOwnerID: oid || null,
      targetOwner:   oid ? ((owners as Record<string, unknown>)[oid] ?? null) : null,
      reporterID:    rid,
      reporter:      (reporters as Record<string, unknown>)[rid] ?? null,
      reason:        String((row as { reason?: unknown }).reason ?? ""),
      notes:         (row as { notes?: unknown }).notes ? String((row as { notes?: unknown }).notes) : null,
      status:        String((row as { status?: unknown }).status ?? "pending"),
      reviewedAt:    (row as { reviewed_at?: unknown }).reviewed_at ? new Date(String((row as { reviewed_at?: unknown }).reviewed_at)).toISOString() : null,
      createdAt:     new Date(String((row as { created_at?: unknown }).created_at ?? new Date().toISOString())).toISOString(),
    };
  });
  return json(payload);
}

async function reviewContentReport(req: Request, viewerID: string, reportID: string): Promise<Response> {
  if (!reportID) return json({ error: "reportID required." }, 400);
  const payload = await req.json().catch(() => ({})) as Record<string, unknown>;
  const status = String(payload.status ?? "").trim().toLowerCase();
  if (!["confirmed", "dismissed"].includes(status)) return json({ error: "Invalid status." }, 400);
  const admin = serviceClient();
  if (!(await isContentReportReviewer(admin, viewerID))) return unauthorized();
  const write = await admin.from("content_reports").update({
    status,
    reviewed_by: viewerID.toLowerCase(),
    reviewed_at: new Date().toISOString(),
    updated_at:  new Date().toISOString(),
  }).eq("id", reportID);
  if (write.error) return json({ error: write.error.message }, 500);
  return json({ ok: true });
}
