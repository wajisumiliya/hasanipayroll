import crypto from "node:crypto";

// Cloudflare R2 supports the S3 SigV4 presigned URL protocol.
// Credentials stay server-side; callers receive short-lived, scoped URLs.
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const hmac = (key, value) => crypto.createHmac("sha256", key).update(value).digest();
const encode = (value) => encodeURIComponent(value).replace(/[!'()*]/g, (c) =>
  "%" + c.charCodeAt(0).toString(16).toUpperCase());

export function r2Configured() {
  return ["R2_ACCOUNT_ID", "R2_BUCKET", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY"]
    .every((name) => Boolean(process.env[name]?.trim()));
}

export function presignEmployeePhoto({ employeeId, method, contentType }) {
  if (!r2Configured()) throw new Error("R2 is not configured");
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(employeeId)) throw new Error("Invalid employee ID");
  if (!["GET", "PUT"].includes(method)) throw new Error("Invalid operation");
  const allowed = ["image/jpeg", "image/png", "image/webp"];
  if (method === "PUT" && !allowed.includes(contentType)) throw new Error("Unsupported photo type");

  const account = process.env.R2_ACCOUNT_ID.trim();
  const bucket = process.env.R2_BUCKET.trim();
  const accessKey = process.env.R2_ACCESS_KEY_ID.trim();
  const secret = process.env.R2_SECRET_ACCESS_KEY.trim();
  if (!/^[a-f0-9]{32}$/.test(account) || !/^[A-Za-z0-9._-]+$/.test(bucket)) {
    throw new Error("Invalid R2 configuration");
  }
  const host = account + ".r2.cloudflarestorage.com";
  const objectKey = "employee-photos/" + employeeId + "/profile";
  const path = "/" + encode(bucket) + "/" + objectKey.split("/").map(encode).join("/");
  const now = new Date();
  const stamp = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const date = stamp.slice(0, 8);
  const scope = date + "/auto/s3/aws4_request";
  const headers = method === "PUT" ? "content-type;host" : "host";
  const signedHeaderText = method === "PUT"
    ? "content-type:" + contentType + "\nhost:" + host + "\n"
    : "host:" + host + "\n";
  const params = {
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": accessKey + "/" + scope,
    "X-Amz-Date": stamp,
    "X-Amz-Expires": "300",
    "X-Amz-SignedHeaders": headers,
  };
  const query = Object.entries(params).sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => encode(k) + "=" + encode(v)).join("&");
  const canonical = [method, path, query, signedHeaderText, headers, "UNSIGNED-PAYLOAD"].join("\n");
  const toSign = ["AWS4-HMAC-SHA256", stamp, scope, sha256(canonical)].join("\n");
  const signingKey = hmac(hmac(hmac(hmac("AWS4" + secret, date), "auto"), "s3"), "aws4_request");
  const signature = crypto.createHmac("sha256", signingKey).update(toSign).digest("hex");
  return {
    url: "https://" + host + path + "?" + query + "&X-Amz-Signature=" + signature,
    headers: method === "PUT" ? { "Content-Type": contentType } : {},
    objectKey,
    expiresIn: 300,
  };
}
