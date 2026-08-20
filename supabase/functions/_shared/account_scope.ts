import { serviceClient } from "./http.ts";

const legacyFounderClusterAccountIDs = new Set([
  "cbc29d93-94c3-4cb8-9f22-cfc53d60c330", // primadonvino (current)
  "283dbe7a-fc81-46ce-91c8-297f75bfd6d1", // primadonvino auth alias (current login subject)
  "cb6f0aa1-2a39-4ede-90b0-af5a63da5a5d", // primadonvino (legacy)
  "4b80ea39-95a4-4389-a55a-6a042294d82f", // scrolls
  "22b5cf34-2285-4e72-b1e8-8fa95a25d3c0", // gelanella
  "ed2e1318-d186-4cc9-b4e9-7e43c5b87a8d", // ovispictures
  "db4251ba-e3d4-4489-a51a-37e2e5a71fcc", // amerigomagazine
  "aec0dcd5-2046-4753-9244-0b5293834e11", // provostodaro
]);

type AccountScope = {
  ownerID: string;
  accountIDs: Set<string>;
};

function normalizeUserID(value: string): string {
  return String(value).trim().toLowerCase();
}

function fallbackLegacyFounderScope(userID: string): AccountScope | null {
  if (!legacyFounderClusterAccountIDs.has(userID)) return null;
  return {
    ownerID: "cbc29d93-94c3-4cb8-9f22-cfc53d60c330",
    accountIDs: new Set(legacyFounderClusterAccountIDs),
  };
}

export async function resolveAccountScopeForUser(userIDRaw: string): Promise<AccountScope | null> {
  const userID = normalizeUserID(userIDRaw);
  if (!userID) return null;
  const founderFallback = fallbackLegacyFounderScope(userID);
  if (founderFallback) return founderFallback;

  const admin = serviceClient();
  const me = await admin.from("users")
    .select("id, owner_id")
    .eq("id", userID)
    .maybeSingle();

  if (me.error || !me.data) {
    const ownedByID = await admin.from("users")
      .select("id")
      .eq("owner_id", userID);
    if (ownedByID.error || (ownedByID.data ?? []).length === 0) {
      return fallbackLegacyFounderScope(userID);
    }

    const accountIDs = new Set<string>();
    for (const row of ownedByID.data ?? []) {
      const id = normalizeUserID(String(row.id ?? ""));
      if (id) accountIDs.add(id);
    }
    accountIDs.add(userID);
    return { ownerID: userID, accountIDs };
  }

  const ownerID = normalizeUserID(String(me.data.owner_id ?? me.data.id ?? userID));
  const owned = await admin.from("users").select("id").eq("owner_id", ownerID);
  const accountIDs = new Set<string>();

  if (!owned.error) {
    for (const row of owned.data ?? []) {
      const id = normalizeUserID(String(row.id ?? ""));
      if (id) accountIDs.add(id);
    }
  }

  // Keep current account in scope even if owner rows are partially missing.
  accountIDs.add(userID);

  // Backward compatibility for legacy founder-managed IDs if owner_id has not fully backfilled yet.
  if (accountIDs.size <= 1 && legacyFounderClusterAccountIDs.has(userID)) {
    for (const legacyID of legacyFounderClusterAccountIDs) {
      accountIDs.add(legacyID);
    }
  }

  return { ownerID, accountIDs };
}

export async function canActAsAccount(authedRaw: string, targetRaw: string): Promise<boolean> {
  const authed = normalizeUserID(authedRaw);
  const target = normalizeUserID(targetRaw);
  if (!authed || !target) return false;
  if (authed == target) return true;

  const scope = await resolveAccountScopeForUser(authed);
  if (!scope) return false;
  return scope.accountIDs.has(target);
}

export async function resolveScopedAccountID(authedRaw: string, requestedRaw: string): Promise<string | null> {
  const authed = normalizeUserID(authedRaw);
  if (!authed) return null;
  const requested = normalizeUserID(requestedRaw);
  if (!requested) {
    // Default to the actively authenticated account when the caller does not
    // explicitly request another account in scope.  Owner-scoped aggregation is
    // still available to downstream route logic via resolveAccountScopeForUser,
    // but the default read target should match the account the user is actually
    // operating as.
    return authed;
  }
  if (requested == authed) return authed;

  const scope = await resolveAccountScopeForUser(authed);
  if (!scope) return null;
  return scope.accountIDs.has(requested) ? requested : null;
}
