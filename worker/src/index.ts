import type { Env, ExtractionInput, JsonRecord, Operation } from "./contracts";
import { IdempotencyObject } from "./idempotency";
export { IdempotencyObject };

const MAX_REQUEST_BYTES = 2_200_000;
const MAX_DOCUMENT_BYTES = 1_500_000;
const MAX_TEXT_CHARS = 300_000;
const MAX_RESPONSE_BYTES = 256_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const IMAGE_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const DOCUMENT_MIME_TYPES = new Set(["application/pdf", "image/jpeg", "image/png", "image/webp"]);
type ErrorCode = "method_not_allowed" | "not_found" | "unsupported_media_type" | "payload_too_large" | "invalid_request" | "rate_limited" | "rate_limit_unavailable" | "idempotency_unavailable";

function errorResponse(status: number, code: ErrorCode, message: string, requestId: string, headers: HeadersInit = {}): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("content-type", "application/json; charset=utf-8");
  return Response.json({ ok: false, requestId, error: { code, message, requestId } }, { status, headers: responseHeaders });
}
function isRecord(value: unknown): value is JsonRecord { return typeof value === "object" && value !== null && !Array.isArray(value); }
function hasExactKeys(value: JsonRecord, keys: string[]): boolean {
  const actual = Object.keys(value).sort(); const expected = [...keys].sort();
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}
function validText(value: unknown, max: number): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.length <= max;
}
function base64DecodedLength(value: string): number {
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.floor((value.length * 3) / 4) - padding;
}
function validBase64(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length % 4 === 0 &&
    /^[A-Za-z0-9+/]+={0,2}$/.test(value) && base64DecodedLength(value) <= MAX_DOCUMENT_BYTES;
}
function validateInput(operation: Operation, value: unknown): value is ExtractionInput {
  if (!isRecord(value)) return false;
  if (operation === "timetable") {
    if (!hasExactKeys(value, ["image"]) || !isRecord(value.image) || !hasExactKeys(value.image, ["mimeType", "data"])) return false;
    return typeof value.image.mimeType === "string" && IMAGE_MIME_TYPES.has(value.image.mimeType) && validBase64(value.image.data);
  }
  if (!hasExactKeys(value, ["document", "program", "semester", "section"]) || !isRecord(value.document)) return false;
  if (!validText(value.program, 120) || !validText(value.semester, 80) || !validText(value.section, 40)) return false;
  if (value.document.mimeType === "text/plain") {
    return hasExactKeys(value.document, ["mimeType", "text"]) && validText(value.document.text, MAX_TEXT_CHARS);
  }
  return hasExactKeys(value.document, ["mimeType", "data"]) &&
    typeof value.document.mimeType === "string" && DOCUMENT_MIME_TYPES.has(value.document.mimeType) &&
    validBase64(value.document.data);
}
async function readLimitedText(request: Request): Promise<string | null> {
  const declared = Number(request.headers.get("content-length") ?? 0);
  if (declared > MAX_REQUEST_BYTES) return null;
  if (!request.body) return "";
  const reader = request.body.getReader(); const chunks: Uint8Array[] = []; let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_REQUEST_BYTES) { await reader.cancel(); return null; }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(total); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(bytes);
}
async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
function logEvent(event: { requestId: string; requestType: string; status: number; durationMs: number; retryCount: number; errorCategory: string | null }): void {
  console.log(JSON.stringify(event));
}
function routeOperation(pathname: string): Operation | null {
  if (pathname === "/v1/extract/timetable") return "timetable";
  if (pathname === "/v1/extract/exam") return "exam";
  return null;
}
export async function handleRequest(request: Request, env: Env): Promise<Response> {
  const startedAt = Date.now(); const url = new URL(request.url);
  const operation = routeOperation(url.pathname); const candidateId = request.headers.get("idempotency-key") ?? "";
  const requestId = UUID_PATTERN.test(candidateId) ? candidateId : crypto.randomUUID();
  const requestType = operation ?? (url.pathname === "/healthz" ? "health" : "unknown");
  if (url.pathname === "/healthz" && request.method === "GET") {
    const response = Response.json({ ok: true, service: "nextclass-gemini-proxy" });
    logEvent({ requestId, requestType, status: response.status, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: null });
    return response;
  }
  if (!operation) {
    const response = errorResponse(404, "not_found", "Endpoint not found.", requestId);
    logEvent({ requestId, requestType, status: 404, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "not_found" });
    return response;
  }
  if (request.method !== "POST") {
    const response = errorResponse(405, "method_not_allowed", "Use POST for extraction.", requestId, { allow: "POST" });
    logEvent({ requestId, requestType, status: 405, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "method_not_allowed" });
    return response;
  }
  if (!UUID_PATTERN.test(candidateId)) {
    const response = errorResponse(400, "invalid_request", "A valid Idempotency-Key is required.", requestId);
    logEvent({ requestId, requestType, status: 400, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "invalid_request" });
    return response;
  }
  const contentType = request.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  if (contentType !== "application/json") {
    const response = errorResponse(415, "unsupported_media_type", "Send an application/json request.", requestId);
    logEvent({ requestId, requestType, status: 415, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "unsupported_media_type" });
    return response;
  }
  const clientAddress = request.headers.get("cf-connecting-ip") ?? "unknown";
  const rateKey = await sha256Hex(clientAddress);
  try {
    const rate = await env.IP_RATE_LIMITER.limit({ key: rateKey });
    if (!rate.success) {
      const response = errorResponse(429, "rate_limited", "Too many scans. Please wait a minute and try again.", requestId, { "retry-after": "60" });
      logEvent({ requestId, requestType, status: 429, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "rate_limited" });
      return response;
    }
  } catch {
    const response = errorResponse(503, "rate_limit_unavailable", "Scanning is temporarily unavailable. Please try again shortly.", requestId);
    logEvent({ requestId, requestType, status: 503, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "rate_limit_unavailable" });
    return response;
  }
  let bodyText: string | null;
  try { bodyText = await readLimitedText(request); } catch { bodyText = ""; }
  if (bodyText === null) {
    const response = errorResponse(413, "payload_too_large", "This file is too large. Choose a smaller image or document.", requestId);
    logEvent({ requestId, requestType, status: 413, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "payload_too_large" });
    return response;
  }
  let parsed: unknown;
  try { parsed = JSON.parse(bodyText); } catch {
    const response = errorResponse(400, "invalid_request", "The extraction request is not valid JSON.", requestId);
    logEvent({ requestId, requestType, status: 400, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "invalid_request" });
    return response;
  }
  if (!validateInput(operation, parsed)) {
    const response = errorResponse(422, "invalid_request", "The selected file or student details are not supported.", requestId);
    logEvent({ requestId, requestType, status: 422, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "invalid_request" });
    return response;
  }
  const fingerprint = await sha256Hex(bodyText);
  const objectName = await sha256Hex(clientAddress + "|" + candidateId);
  try {
    const stub = env.IDEMPOTENCY.get(env.IDEMPOTENCY.idFromName(objectName));
    const internal = await stub.fetch(new Request("https://idempotency.internal/execute", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ requestId, operation, fingerprint, payload: parsed }),
    }));
    const internalBody = await readResponseLimited(internal, MAX_RESPONSE_BYTES);
    const status = internalBody === null ? 502 : internal.status;
    const safeBody = internalBody ?? JSON.stringify({ ok: false, requestId, error: { code: "invalid_upstream_response", message: "The AI service returned an unreadable response.", requestId } });
    const retryCount = Number(internal.headers.get("x-nc-retries") ?? "0") || 0;
    const errorCategory = internal.headers.get("x-nc-error-category");
    const responseHeaders = new Headers({ "content-type": "application/json; charset=utf-8", "x-request-id": requestId });
    const retryAfter = internal.headers.get("retry-after");
    if (retryAfter) responseHeaders.set("retry-after", retryAfter);
    const response = new Response(safeBody, { status, headers: responseHeaders });
    logEvent({ requestId, requestType, status, durationMs: Date.now() - startedAt, retryCount, errorCategory });
    return response;
  } catch {
    const response = errorResponse(503, "idempotency_unavailable", "Scanning is temporarily unavailable. Please try again shortly.", requestId);
    logEvent({ requestId, requestType, status: 503, durationMs: Date.now() - startedAt, retryCount: 0, errorCategory: "idempotency_unavailable" });
    return response;
  }
}
async function readResponseLimited(response: Response, maxBytes: number): Promise<string | null> {
  const reader = response.body?.getReader(); if (!reader) return "";
  const chunks: Uint8Array[] = []; let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read(); if (done) break;
      total += value.byteLength;
      if (total > maxBytes) { await reader.cancel(); return null; }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(total); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(bytes);
}
export default { fetch: handleRequest };
