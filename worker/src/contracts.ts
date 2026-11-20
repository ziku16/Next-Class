export type Operation = "timetable" | "exam";
export type JsonRecord = Record<string, unknown>;
export type TimetableInput = { image: { mimeType: "image/jpeg" | "image/png" | "image/webp"; data: string } };
export type ExamDocument =
  | { mimeType: "text/plain"; text: string }
  | { mimeType: "application/pdf" | "image/jpeg" | "image/png" | "image/webp"; data: string };
export type ExamInput = { document: ExamDocument; program: string; semester: string; section: string };
export type ExtractionInput = TimetableInput | ExamInput;
export interface RateLimitBinding { limit(options: { key: string }): Promise<{ success: boolean }>; }
export interface DurableStorage {
  get<T>(key: string): Promise<T | undefined>;
  put<T>(key: string, value: T): Promise<void>;
  delete(key: string): Promise<boolean>;
  setAlarm(timestamp: number): Promise<void>;
}
export interface DurableObjectStateLike { storage: DurableStorage; }
export interface DurableObjectStubLike { fetch(request: Request): Promise<Response>; }
export interface DurableObjectNamespaceLike { idFromName(name: string): unknown; get(id: unknown): DurableObjectStubLike; }
export interface Env {
  GEMINI_API_KEY: string;
  IP_RATE_LIMITER: RateLimitBinding;
  IDEMPOTENCY: DurableObjectNamespaceLike;
}