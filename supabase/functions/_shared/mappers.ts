import { AppUser, mapUser, serviceClient, SUMMARY_USER_COLUMNS } from "./http.ts";

export async function fetchUsersByIds(userIds: string[]): Promise<Record<string, AppUser>> {
  const uniqueIds = Array.from(new Set(userIds.map((id) => String(id ?? "").trim()).filter(Boolean)));
  if (uniqueIds.length === 0) return {};
  const admin = serviceClient();
  const { data } = await admin.from("account_profiles").select(SUMMARY_USER_COLUMNS).in("id", uniqueIds);
  const rows = (data ?? []) as Record<string, unknown>[];
  const map: Record<string, AppUser> = {};
  for (const row of rows) {
    const user = mapUser(row);
    map[user.id] = user;
  }

  const missingIds = uniqueIds.filter((id) => !map[id]);
  if (missingIds.length > 0) {
    const fallback = await admin.from("users").select(SUMMARY_USER_COLUMNS).in("id", missingIds);
    const fallbackRows = (fallback.data ?? []) as Record<string, unknown>[];
    for (const row of fallbackRows) {
      const user = mapUser(row);
      map[user.id] = user;
    }
  }

  return map;
}

export type BackendPost = {
  id: string;
  author: AppUser;
  rescrollOrigin?: {
    postID: string;
    user: AppUser;
    caption: string | null;
    websiteURL: string | null;
    timestamp: string;
  } | null;
  quoteText: string | null;
  quote_text?: string | null;
  type: "text" | "photo" | "video";
  caption: string | null;
  websiteURL: string | null;
  website_url?: string | null;
  locationCity: string | null;
  location_city?: string | null;
  textBody: string | null;
  text_body?: string | null;
  assetRef: string | null;
  asset_ref?: string | null;
  assetProvider: string | null;
  asset_provider?: string | null;
  assetBucket: string | null;
  asset_bucket?: string | null;
  assetObjectKey: string | null;
  asset_object_key?: string | null;
  coverImageRef: string | null;
  cover_image_ref?: string | null;
  coverProvider: string | null;
  cover_provider?: string | null;
  coverBucket: string | null;
  cover_bucket?: string | null;
  coverObjectKey: string | null;
  cover_object_key?: string | null;
  aspectRatio: number | null;
  aspect_ratio?: number | null;
  createdAt: string;
  created_at?: string;
};

export function mapPost(
  row: Record<string, unknown>,
  author: AppUser,
  rescrollOrigin: BackendPost["rescrollOrigin"] = null,
): BackendPost {
  const websiteURL = (row.website_url as string | null) ?? null;
  const locationCity = (row.location_city as string | null) ?? null;
  const textBody = (row.text_body as string | null) ?? null;
  const assetRef = (row.asset_ref as string | null) ?? null;
  const assetProvider = (row.asset_provider as string | null) ?? null;
  const assetBucket = (row.asset_bucket as string | null) ?? null;
  const assetObjectKey = (row.asset_object_key as string | null) ?? null;
  const coverImageRef = (row.cover_image_ref as string | null) ?? null;
  const coverProvider = (row.cover_provider as string | null) ?? null;
  const coverBucket = (row.cover_bucket as string | null) ?? null;
  const coverObjectKey = (row.cover_object_key as string | null) ?? null;
  const aspectRatio = typeof row.aspect_ratio === "number" ? row.aspect_ratio : null;
  const createdAt = new Date(String(row.created_at)).toISOString();
  const quoteText = String(row.quote_text ?? "").trim() || null;
  return {
    id: String(row.id),
    author,
    rescrollOrigin,
    quoteText,
    quote_text: quoteText,
    type: (row.type as "text" | "photo" | "video") ?? "text",
    caption: (row.caption as string | null) ?? null,
    websiteURL,
    website_url: websiteURL,
    locationCity,
    location_city: locationCity,
    textBody,
    text_body: textBody,
    assetRef,
    asset_ref: assetRef,
    assetProvider,
    asset_provider: assetProvider,
    assetBucket,
    asset_bucket: assetBucket,
    assetObjectKey,
    asset_object_key: assetObjectKey,
    coverImageRef,
    cover_image_ref: coverImageRef,
    coverProvider,
    cover_provider: coverProvider,
    coverBucket,
    cover_bucket: coverBucket,
    coverObjectKey,
    cover_object_key: coverObjectKey,
    aspectRatio,
    aspect_ratio: aspectRatio,
    createdAt,
    created_at: createdAt,
  };
}

const PUBLIC_LIST_TEXT_BODY_LIMIT = 700;
const PUBLIC_LIST_RESCROLL_CAPTION_LIMIT = 1200;

function compactText(value: string | null | undefined, limit: number): string | null {
  if (!value) return null;
  if (value.length <= limit) return value;
  return `${value.slice(0, limit).trimEnd()}...`;
}

export function compactPostForPublicList(post: BackendPost): BackendPost {
  const textBody = compactText(post.textBody, PUBLIC_LIST_TEXT_BODY_LIMIT);
  const rescrollOrigin = post.rescrollOrigin
    ? {
      ...post.rescrollOrigin,
      caption: compactText(post.rescrollOrigin.caption, PUBLIC_LIST_RESCROLL_CAPTION_LIMIT),
    }
    : post.rescrollOrigin;

  return {
    ...post,
    textBody,
    text_body: textBody,
    rescrollOrigin,
  };
}
