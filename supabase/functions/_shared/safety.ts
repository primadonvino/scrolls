import { serviceClient } from "./http.ts";

export const SAFETY_REPORT_REASONS = new Set([
  "spam",
  "harassment_bullying",
  "hate_speech_discrimination",
  "nudity_sexual_themes",
  "violence",
  "drugs",
  "misinformation",
  "copyright_violation",
  "impersonation",
]);

export function normalizeReportReason(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

export function normalizeReportNotes(value: unknown): string | null {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return null;
  return trimmed.slice(0, 1000);
}

export function isValidSafetyReportReason(reason: string): boolean {
  return SAFETY_REPORT_REASONS.has(reason);
}

export async function mutuallyBlockedUserIDs(
  admin: ReturnType<typeof serviceClient>,
  userIDs: string[],
): Promise<Set<string>> {
  const ids = Array.from(new Set(
    userIDs
      .map((value) => String(value ?? "").trim().toLowerCase())
      .filter((value) => value.length > 0),
  ));
  if (ids.length === 0) return new Set();

  const rows = await admin.from("user_blocks")
    .select("blocker_id, blocked_id")
    .or(`blocker_id.in.(${ids.join(",")}),blocked_id.in.(${ids.join(",")})`);
  if (rows.error || !rows.data) return new Set();

  const blocked = new Set<string>();
  const idSet = new Set(ids);
  for (const row of rows.data as Array<Record<string, unknown>>) {
    const blocker = String(row.blocker_id ?? "").trim().toLowerCase();
    const blockedID = String(row.blocked_id ?? "").trim().toLowerCase();
    if (idSet.has(blocker) && blockedID) blocked.add(blockedID);
    if (idSet.has(blockedID) && blocker) blocked.add(blocker);
  }
  return blocked;
}

export async function hasMutualBlock(
  admin: ReturnType<typeof serviceClient>,
  leftUserID: string,
  rightUserID: string,
): Promise<boolean> {
  const left = String(leftUserID ?? "").trim().toLowerCase();
  const right = String(rightUserID ?? "").trim().toLowerCase();
  if (!left || !right || left === right) return false;

  const rows = await admin.from("user_blocks")
    .select("id")
    .or(
      `and(blocker_id.eq.${left},blocked_id.eq.${right}),` +
      `and(blocker_id.eq.${right},blocked_id.eq.${left})`,
    )
    .limit(1);
  if (rows.error) return false;
  return Boolean(rows.data?.length);
}
