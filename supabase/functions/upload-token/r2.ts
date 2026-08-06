import { PutObjectCommand, S3Client } from "npm:@aws-sdk/client-s3@3.726.1";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.726.1";

export type R2PresignedUploadInput = {
  accountID: string;
  accessKeyID: string;
  secretAccessKey: string;
  bucket: string;
  objectKey: string;
  contentType: string;
  expiresInSeconds: number;
};

export type R2BucketCorsInput = {
  accountID: string;
  apiToken: string;
  bucket: string;
  allowedOrigins: string[];
};

function createR2Client(input: Pick<R2PresignedUploadInput, "accountID" | "accessKeyID" | "secretAccessKey">): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: `https://${input.accountID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: input.accessKeyID,
      secretAccessKey: input.secretAccessKey,
    },
    forcePathStyle: true,
  });
}

export async function ensureR2BucketCors(input: R2BucketCorsInput): Promise<void> {
  const origins = Array.from(new Set(input.allowedOrigins.map((origin) => origin.trim()).filter(Boolean)));
  if (origins.length === 0) return;
  const endpoint = `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(input.accountID)}`
    + `/r2/buckets/${encodeURIComponent(input.bucket)}/cors`;
  const response = await fetch(endpoint, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${input.apiToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      rules: [
        {
          id: "scrolls-web-uploads",
          allowed: {
            origins,
            methods: ["PUT", "GET", "HEAD"],
            headers: ["Content-Type", "Cache-Control"],
          },
          exposeHeaders: ["ETag"],
          maxAgeSeconds: 3600,
        },
      ],
    }),
  });

  const payload = await response.json().catch(() => null) as {
    success?: boolean;
    errors?: Array<{ message?: string }>;
  } | null;
  if (!response.ok || payload?.success !== true) {
    const detail = payload?.errors?.map((error) => error.message).filter(Boolean).join("; ");
    throw new Error(detail || `Cloudflare rejected the bucket CORS policy (HTTP ${response.status}).`);
  }
}

export async function createR2PresignedUploadURL(input: R2PresignedUploadInput): Promise<string> {
  const client = createR2Client(input);

  const command = new PutObjectCommand({
    Bucket: input.bucket,
    Key: input.objectKey,
    ContentType: input.contentType,
    // Mark uploads as immutable — unique objectKeys mean the content never changes,
    // so Cloudflare CDN and device caches can hold these for a full year.
    CacheControl: "public, max-age=31536000, immutable",
  });

  return await getSignedUrl(client, command, { expiresIn: input.expiresInSeconds });
}
