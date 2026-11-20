import { afterEach, describe, expect, it, vi } from "vitest";
import { handleRequest, IdempotencyObject } from "../src/index";
import type { DurableObjectNamespaceLike, DurableObjectStateLike, DurableStorage, Env } from "../src/contracts";

const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const TEST_KEY = "test-only-worker-secret-never-log";
const VALID_ENTRY = {
  day: "Monday", subject: "Data Structures", group: null,
  start: "09:00", end: "10:30", room: "A-204", teacher: "Dr Test",
};
const VALID_EXAM = {
  subject: "Data Structures", date: "2026-12-15", startTime: "09:00", endTime: "12:00",
  program: "BS Computer Science", semester: "Semester 3", section: "A",
  venue: "Main Hall", examType: "Final",
};

class MemoryStorage implements DurableStorage {
  values = new Map<string, unknown>();
  alarmAt: number | null = null;
  async get<T>(key: string): Promise<T | undefined> { return this.values.get(key) as T | undefined; }
  async put<T>(key: string, value: T): Promise<void> { this.values.set(key, value); }
  async delete(key: string): Promise<boolean> { return this.values.delete(key); }
  async setAlarm(timestamp: number): Promise<void> { this.alarmAt = timestamp; }
}
class MemoryState implements DurableObjectStateLike {
  constructor(readonly storage: MemoryStorage) {}
}
class MemoryNamespace implements DurableObjectNamespaceLike {
  private objects = new Map<string, IdempotencyObject>();
  constructor(private env: () => Env) {}
  idFromName(name: string): unknown { return name; }
  get(id: unknown) {
    const key = String(id);
    let object = this.objects.get(key);
    if (!object) {
      object = new IdempotencyObject(new MemoryState(new MemoryStorage()), this.env());
      this.objects.set(key, object);
    }
    return { fetch: (request: Request) => object!.fetch(request) };
  }
}
function createEnv(rate: () => Promise<boolean> = async () => true) {
  let env: Env;
  const namespace = new MemoryNamespace(() => env);
  env = {
    GEMINI_API_KEY: TEST_KEY,
    IP_RATE_LIMITER: { limit: async () => ({ success: await rate() }) },
    IDEMPOTENCY: namespace,
  };
  return env;
}
function successResponse(data: unknown): Response {
  return Response.json({ candidates: [{ content: { parts: [{ text: JSON.stringify(data) }] } }] });
}
function timetableBody(data = "aW1hZ2U=") {
  return { image: { mimeType: "image/jpeg", data } };
}
function examBody() {
  return {
    document: { mimeType: "application/pdf", data: "JVBERg==" },
    program: "BS Computer Science", semester: "Semester 3", section: "A",
  };
}
function request(path = "/v1/extract/timetable", body: unknown = timetableBody(), headers: Record<string, string> = {}) {
  return new Request("https://worker.test" + path, {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": REQUEST_ID, "cf-connecting-ip": "192.0.2.5", ...headers },
    body: JSON.stringify(body),
  });
}
async function json(response: Response) { return await response.json() as Record<string, any>; }
afterEach(() => vi.restoreAllMocks());

describe("Worker extraction API", () => {
  it("returns a non-sensitive health response", async () => {
    const response = await handleRequest(new Request("https://worker.test/healthz"), createEnv());
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true, service: "nextclass-gemini-proxy" });
  });

  it("forwards a fixed timetable request and returns validated JSON", async () => {
    let observedGenerationConfig: Record<string, unknown> | undefined;
    const upstream = vi.fn(async (_url: RequestInfo | URL, init?: RequestInit) => {
      expect(new Headers(init?.headers).get("x-goog-api-key")).toBe(TEST_KEY);
      expect(String(_url)).toContain("/models/gemini-3.5-flash-lite:generateContent");
      const body = JSON.parse(String(init?.body));
      observedGenerationConfig = body.generationConfig;
      expect(body.generationConfig.maxOutputTokens).toBe(3072);
      expect(body.contents[0].parts[1].inlineData.data).toBe("aW1hZ2U=");
      return successResponse({ entries: [VALID_ENTRY] });
    });
    vi.stubGlobal("fetch", upstream);
    const response = await handleRequest(request(), createEnv());
    expect(response.status).toBe(200);
    expect(observedGenerationConfig?.responseSchema).toMatchObject({ type: "OBJECT" });
    expect(await json(response)).toMatchObject({ ok: true, data: { entries: [VALID_ENTRY] } });
    expect(upstream).toHaveBeenCalledTimes(1);
  });

  it("fails safely when the Cloudflare Gemini secret is missing", async () => {
    const upstream = vi.fn();
    vi.stubGlobal("fetch", upstream);
    const env = createEnv();
    env.GEMINI_API_KEY = "";
    const response = await handleRequest(request(), env);
    expect(response.status).toBe(503);
    expect((await json(response)).error.code).toBe("upstream_authentication");
    expect(upstream).not.toHaveBeenCalled();
  });
  it("forwards an exam document and selected identity", async () => {
    const upstream = vi.fn(async (_url: RequestInfo | URL, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body));
      expect(body.generationConfig.maxOutputTokens).toBe(2048);
      expect(body.contents[0].parts[1].inlineData.mimeType).toBe("application/pdf");
      expect(body.contents[0].parts[1].inlineData.data).toBe("JVBERg==");
      expect(body.contents[0].parts[0].text).toContain('section="A"');
      return successResponse({ exams: [VALID_EXAM] });
    });
    vi.stubGlobal("fetch", upstream);
    const response = await handleRequest(request("/v1/extract/exam", examBody()), createEnv());
    expect(response.status).toBe(200);
    expect(await json(response)).toMatchObject({ ok: true, data: { exams: [VALID_EXAM] } });
  });

  it("rejects unsupported content types and malformed documents before Gemini", async () => {
    const upstream = vi.fn();
    vi.stubGlobal("fetch", upstream);
    const env = createEnv();
    const typeResponse = await handleRequest(request("/v1/extract/timetable", timetableBody(), { "content-type": "text/plain" }), env);
    expect(typeResponse.status).toBe(415);
    const invalid = await handleRequest(request("/v1/extract/timetable", { image: { mimeType: "image/svg+xml", data: "PHN2Zz4=" } }), env);
    expect(invalid.status).toBe(422);
    expect(upstream).not.toHaveBeenCalled();
  });

  it("enforces the streamed body limit", async () => {
    const upstream = vi.fn();
    vi.stubGlobal("fetch", upstream);
    const tooLarge = new Request("https://worker.test/v1/extract/timetable", {
      method: "POST",
      headers: { "content-type": "application/json", "idempotency-key": REQUEST_ID, "cf-connecting-ip": "192.0.2.5" },
      body: "x".repeat(2_200_001),
    });
    const response = await handleRequest(tooLarge, createEnv());
    expect(response.status).toBe(413);
    expect((await json(response)).error.code).toBe("payload_too_large");
    expect(upstream).not.toHaveBeenCalled();
  });

  it("enforces rate limits and fails closed if the rate limiter is unavailable", async () => {
    const upstream = vi.fn();
    vi.stubGlobal("fetch", upstream);
    const limited = await handleRequest(request(), createEnv(async () => false));
    expect(limited.status).toBe(429);
    expect(limited.headers.get("retry-after")).toBe("60");
    const unavailable = await handleRequest(request(), {
      ...createEnv(),
      IP_RATE_LIMITER: { limit: async () => { throw new Error("internal-only"); } },
    });
    expect(unavailable.status).toBe(503);
    expect(upstream).not.toHaveBeenCalled();
  });

  it("classifies known schema configuration errors without logging provider text", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, status: "INVALID_ARGUMENT", message: "Invalid value for generationConfig.responseSchema; PRIVATE_TEXT_MUST_NOT_LOG",
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    expect(response.status).toBe(503);
    expect((await json(response)).error.code).toBe("upstream_configuration");
    expect(logs.join("\\n")).toContain("generation_configuration_rejected");
    expect(logs.join("\\n")).not.toContain("PRIVATE_TEXT_MUST_NOT_LOG");
  });
  it("classifies an invalid Gemini API key without returning provider details", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, status: "INVALID_ARGUMENT", message: "API key not valid; DO_NOT_RETURN_PROVIDER_BODY",
      details: [{ reason: "API_KEY_INVALID", metadata: { service: "generativelanguage.googleapis.com" } }],
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    const responseText = await response.text();
    expect(response.status).toBe(503);
    expect(responseText).toContain("upstream_authentication");
    expect(responseText).not.toContain("DO_NOT_RETURN_PROVIDER_BODY");
  });
  it("classifies application-restricted Gemini keys without exposing provider details", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, status: "PERMISSION_DENIED", message: "Requests from this application are blocked; PRIVATE_PROVIDER_TEXT",
      details: [{ reason: "API_KEY_HTTP_REFERRER_BLOCKED" }],
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    const responseText = await response.text();
    expect(response.status).toBe(503);
    expect(responseText).toContain("upstream_authentication");
    expect(logs.join("\n")).toContain("auth_application_restricted_key");
    expect(logs.join("\n")).not.toContain("PRIVATE_PROVIDER_TEXT");
  });
  it("classifies project access failures using allowlisted provider reason codes", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, status: "FAILED_PRECONDITION", message: "Project access is restricted; PRIVATE_PROVIDER_TEXT",
      details: [{ reason: "USER_PROJECT_DENIED" }],
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    const responseText = await response.text();
    expect(response.status).toBe(503);
    expect(responseText).toContain("upstream_authentication");
    expect(logs.join("\n")).toContain("auth_project_access_denied");
    expect(logs.join("\n")).not.toContain("PRIVATE_PROVIDER_TEXT");
  });
  it("classifies generic invalid-argument messages without logging provider text", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, message: "Unknown field contents in GenerateContentRequest; PRIVATE_PROVIDER_TEXT",
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    const responseText = await response.text();
    expect(response.status).toBe(422);
    expect(responseText).not.toContain("PRIVATE_PROVIDER_TEXT");
    expect(logs.join("\n")).toContain("request_schema_rejected");
    expect(logs.join("\n")).not.toContain("PRIVATE_PROVIDER_TEXT");
  });
  it("classifies structured-output field violations without logging descriptions", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: {
      code: 400, status: "INVALID_ARGUMENT", message: "Invalid request",
      details: [{ fieldViolations: [{ field: "generationConfig.responseSchema", description: "PRIVATE_PROVIDER_TEXT" }] }],
    } }, { status: 400 })));
    const response = await handleRequest(request(), createEnv());
    expect(response.status).toBe(503);
    expect((await json(response)).error.code).toBe("upstream_configuration");
    expect(logs.join("\n")).toContain("generation_configuration_rejected");
    expect(logs.join("\n")).not.toContain("PRIVATE_PROVIDER_TEXT");
  });
  it("records a sanitized provider error-body shape when its message is missing", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ error: { code: 400, status: "INVALID_ARGUMENT" } }, { status: 400 })));
    await handleRequest(request(), createEnv());
    expect(logs.join("\n")).toContain("provider_message_missing_json_error_object");
  });
  it("records only sanitized content-type and size classes for unreadable provider errors", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => new Response("PRIVATE_PROVIDER_BODY", {
      status: 400, headers: { "content-type": "text/plain", "content-length": "21" },
    })));
    await handleRequest(request(), createEnv());
    expect(logs.join("\n")).toContain("text_content_type_small_body");
    expect(logs.join("\n")).not.toContain("PRIVATE_PROVIDER_BODY");
  });
  it.each([
    [400, 422, "invalid_document", 1],
    [401, 503, "upstream_authentication", 1],
    [403, 503, "upstream_authentication", 1],
    [404, 503, "upstream_model_unavailable", 1],
    [429, 429, "upstream_rate_limited", 1],
    [500, 502, "upstream_server_error", 2],
    [503, 503, "upstream_unavailable", 2],
  ])("normalizes Gemini HTTP %i without leaking its body", async (upstreamStatus, expectedStatus, code, calls) => {
    const upstream = vi.fn(async () => new Response("UPSTREAM_BODY_MUST_NOT_ESCAPE", { status: Number(upstreamStatus), headers: Number(upstreamStatus) === 429 ? { "retry-after": "8" } : {} }));
    vi.stubGlobal("fetch", upstream);
    const response = await handleRequest(request(), createEnv());
    const responseText = await response.text();
    expect(response.status).toBe(Number(expectedStatus));
    expect(responseText).toContain(String(code));
    expect(responseText).not.toContain("UPSTREAM_BODY_MUST_NOT_ESCAPE");
    expect(upstream).toHaveBeenCalledTimes(Number(calls));
    if (Number(upstreamStatus) === 429) expect(response.headers.get("retry-after")).toBe("8");
  });

  it("retries one transient upstream 503 and logs only safe metadata", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    const upstream = vi.fn()
      .mockResolvedValueOnce(new Response("temporary", { status: 503 }))
      .mockResolvedValueOnce(successResponse({ entries: [VALID_ENTRY] }));
    vi.stubGlobal("fetch", upstream);
    const response = await handleRequest(request(), createEnv());
    expect(response.status).toBe(200);
    expect(upstream).toHaveBeenCalledTimes(2);
    expect(logs.join("\n")).not.toContain(TEST_KEY);
    expect(logs.join("\n")).not.toContain("aW1hZ2U=");
    expect(logs.join("\n")).toContain('"retryCount":1');
  });

  it("normalizes timeouts and network failures without retrying ambiguous upstream work", async () => {
    const timeout = vi.fn(async () => { const error = new Error("timeout"); error.name = "TimeoutError"; throw error; });
    vi.stubGlobal("fetch", timeout);
    const timeoutResponse = await handleRequest(request(), createEnv());
    expect(timeoutResponse.status).toBe(504);
    expect(timeout).toHaveBeenCalledTimes(1);

    const offline = vi.fn(async () => { throw new TypeError("offline"); });
    vi.stubGlobal("fetch", offline);
    const offlineResponse = await handleRequest(request(), createEnv());
    expect(offlineResponse.status).toBe(502);
    expect(offline).toHaveBeenCalledTimes(1);
  });

  it("returns in-progress for concurrent retries and sends one upstream generation", async () => {
    let release!: (response: Response) => void;
    const upstream = vi.fn(async () => await new Promise<Response>((resolve) => { release = resolve; }));
    vi.stubGlobal("fetch", upstream);
    const env = createEnv();
    const firstPromise = handleRequest(request(), env);
    await vi.waitFor(() => expect(upstream).toHaveBeenCalledTimes(1));
    const duplicate = await handleRequest(request(), env);
    expect(duplicate.status).toBe(409);
    expect((await json(duplicate)).error.code).toBe("request_in_progress");
    expect(upstream).toHaveBeenCalledTimes(1);
    release(successResponse({ entries: [VALID_ENTRY] }));
    expect((await firstPromise).status).toBe(200);
  });

  it("times out while reading a stalled upstream response body", async () => {
    vi.useFakeTimers();
    try {
      const body = new ReadableStream<Uint8Array>({ pull: () => new Promise<void>(() => {}) });
      let resolveFetched!: () => void;
      const fetched = new Promise<void>((resolve) => { resolveFetched = resolve; });
      vi.stubGlobal("fetch", vi.fn(async () => { resolveFetched(); return new Response(body, { status: 200 }); }));
      const pending = handleRequest(request(), createEnv());
      await fetched;
      await vi.advanceTimersByTimeAsync(25_001);
      const response = await pending;
      expect(response.status).toBe(504);
      expect((await json(response)).error.code).toBe("upstream_timeout");
    } finally {
      vi.useRealTimers();
    }
  });
  it("deduplicates repeated requests and rejects key reuse with changed content", async () => {
    const upstream = vi.fn(async () => successResponse({ entries: [VALID_ENTRY] }));
    vi.stubGlobal("fetch", upstream);
    const env = createEnv();
    const first = await handleRequest(request(), env);
    const replay = await handleRequest(request(), env);
    expect(first.status).toBe(200);
    expect(replay.status).toBe(200);
    expect(await replay.json()).toEqual(await first.json());
    expect(upstream).toHaveBeenCalledTimes(1);

    const conflict = await handleRequest(request("/v1/extract/timetable", timetableBody("Ym90aGVy")), env);
    expect(conflict.status).toBe(409);
    expect((await json(conflict)).error.code).toBe("idempotency_conflict");
    expect(upstream).toHaveBeenCalledTimes(1);
  });

  it("does not return or log the Gemini key", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((value) => logs.push(String(value)));
    vi.stubGlobal("fetch", vi.fn(async () => successResponse({ entries: [VALID_ENTRY] })));
    const response = await handleRequest(request(), createEnv());
    const output = await response.text();
    expect(output).not.toContain(TEST_KEY);
    expect(logs.join("\n")).not.toContain(TEST_KEY);
    expect(output).not.toContain("x-goog-api-key");
  });
});
