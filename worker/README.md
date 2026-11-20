# NextClass Gemini Worker

A constrained Cloudflare Worker proxy for timetable and examination-sheet extraction. The Worker owns the Gemini model, prompts, schemas, and GEMINI_API_KEY; Flutter sends only file content and exam identity fields.

## Routes

- POST /v1/extract/timetable
  - JSON: { "image": { "mimeType": "image/jpeg|image/png|image/webp", "data": "<base64>" } }
- POST /v1/extract/exam
  - JSON: { "document": { "mimeType": "application/pdf|image/jpeg|image/png|image/webp", "data": "<base64>" }, "program": "...", "semester": "...", "section": "..." }
  - XLSX files are parsed locally by Flutter and sent as bounded text/plain extracted cell text.
- GET /healthz

Every extraction request requires an Idempotency-Key UUID. Success responses are { ok: true, requestId, data }; errors use { ok: false, requestId, error: { code, message, requestId } }.

## Security and reliability

- The fixed model is gemini-3.5-flash-lite. Clients cannot choose models, prompts, upstream URLs, or token limits.
- Gemini credentials are read only from the Cloudflare GEMINI_API_KEY secret.
- JSON is capped at 2.2 MB; decoded documents at 1.5 MB; extracted XLSX text at 300,000 characters. Only JSON content type and explicit MIME types are accepted.
- A Cloudflare Rate Limiting binding allows 5 extraction requests per minute per IP key. The IP is hashed before use and is never logged. Cloudflare documents these binding counters as approximate and separate per location, so distributed clients or multiple locations can exceed the configured value. This endpoint has no robust end-user authentication and remains a public paid-upstream surface; an attacker can rotate IPs. Use Cloudflare account spending limits and monitor usage. Stronger guarantees require account-backed client authentication or a different abuse-control design.
- A SQLite-backed Durable Object deduplicates the same IP + idempotency key, rejects key reuse with different content, and caches the normalized result for five minutes. Uploaded image/document bytes are not stored; the small extraction result is temporarily stored to replay duplicate requests.
- Gemini calls time out after 25 seconds. Only HTTP 500/503 get one retry after a short delay; 400/401/403/404/429 are not retried. Timeouts and connection failures are not retried because Gemini does not provide a request idempotency guarantee and a timed-out generation may still have been processed.
- Gemini error bodies and document contents are never returned or logged. Structured logs contain only request ID, operation, status, duration, retry count, and a fixed error category.
- CORS is not used as authentication. There is no embedded app token or package-name check.

Cloudflare currently supports SQLite-backed Durable Objects on Workers Free. The free plan has a 10 ms CPU limit per Worker request; these payload limits are deliberately modest, but very large document parsing or account-level limits may require a paid plan. Review current Workers limits at https://developers.cloudflare.com/workers/platform/limits/, rate limiting behavior at https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/, and Durable Objects pricing at https://developers.cloudflare.com/durable-objects/platform/pricing/.

## Local development

From worker/:

    npm install
    Copy-Item .dev.vars.example .dev.vars
    # Set GEMINI_API_KEY in the ignored .dev.vars file.
    npm run dev

## Flutter configuration

Set the public Worker origin at build time with `--dart-define=NEXTCLASS_WORKER_URL=https://<worker-name>.<account-subdomain>.workers.dev`. This URL is routing configuration, not a credential. The Flutter project no longer has a Gemini API key define or direct Gemini SDK dependency.

## Cloudflare setup and deployment

These commands are documented, not run by this task:

    cd worker
    npm install
    npx wrangler login
    npx wrangler secret put GEMINI_API_KEY
    npx wrangler dev
    npx wrangler deploy

If the account already uses rate-limit namespace ID 739104, replace namespace_id in wrangler.toml with another positive integer unique to that Cloudflare account. Review bindings and SQLite migration before first deploy. wrangler secret put prompts for the value; do not put it in a command argument or source file.

To run actual deployed extraction checks after deployment, provide representative local timetable and date-sheet fixtures:

    $env:WORKER_BASE_URL = "https://<deployed-worker>.workers.dev"
    $env:TIMETABLE_FILE = "C:\path\to\timetable.png"
    $env:EXAM_FILE = "C:\path\to\datesheet.pdf"
    npm run e2e

The E2E script makes one request per file and prints only validated counts. Deployment and live E2E are required before the Android release gate.

## Previous Worker diagnosis

No Worker implementation, Wrangler configuration, or Worker-related commits exist in the repository history available for this task, so the prior Worker's specific failure cannot be established from repository evidence. This implementation makes model selection, prompts, request schema, secrets, status normalization, timeouts, retries, and deduplication explicit and testable instead of forwarding a caller-controlled Gemini request.