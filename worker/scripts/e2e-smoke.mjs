import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { extname } from "node:path";

const baseUrl = process.env.WORKER_BASE_URL?.replace(/\/+$/, "");
const timetablePath = process.env.TIMETABLE_FILE;
const examPath = process.env.EXAM_FILE;
const program = process.env.EXAM_PROGRAM ?? "BS Computer Science";
const semester = process.env.EXAM_SEMESTER ?? "Semester 3";
const section = process.env.EXAM_SECTION ?? "A";

if (!baseUrl || !timetablePath || !examPath) {
  console.error("Set WORKER_BASE_URL, TIMETABLE_FILE, and EXAM_FILE.");
  process.exit(2);
}

function mimeFor(path) {
  const extension = extname(path).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".webp") return "image/webp";
  if (extension === ".pdf") return "application/pdf";
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  throw new Error("Use a PNG, JPEG, WebP, or PDF fixture.");
}

async function post(path, payload, idempotencyKey = randomUUID()) {
  const response = await fetch(baseUrl + path, {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": idempotencyKey },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(40_000),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || body?.ok !== true) {
    console.error("Worker E2E failed:", response.status, body?.error?.code ?? "invalid_response");
    process.exit(1);
  }
  return { data: body.data, idempotencyKey };
}

function validateTimetable(data) {
  if (!Array.isArray(data?.entries) || data.entries.length === 0 || data.entries.length > 100) return false;
  const days = new Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]);
  const time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
  return data.entries.every((row) => row && typeof row === "object" && days.has(row.day) &&
    typeof row.subject === "string" && row.subject.trim().length > 0 && time.test(row.start) && time.test(row.end) &&
    (row.group === null || typeof row.group === "string") &&
    (row.room === null || typeof row.room === "string") &&
    (row.teacher === null || typeof row.teacher === "string"));
}

function validDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(value + "T00:00:00Z");
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
}
function validateExams(data) {
  if (!Array.isArray(data?.exams) || data.exams.length === 0 || data.exams.length > 100) return false;
  const time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
  return data.exams.every((row) => row && typeof row === "object" &&
    typeof row.subject === "string" && row.subject.trim().length > 0 && validDate(row.date) &&
    (row.startTime === null || time.test(row.startTime)) &&
    (row.endTime === null || time.test(row.endTime)) &&
    (row.program === null || typeof row.program === "string") &&
    (row.semester === null || typeof row.semester === "string") &&
    (row.section === null || typeof row.section === "string") &&
    (row.venue === null || typeof row.venue === "string") &&
    (row.examType === null || typeof row.examType === "string"));
}

const timetableBytes = await readFile(timetablePath);
const timetableRequest = {
  image: { mimeType: mimeFor(timetablePath), data: timetableBytes.toString("base64") },
};
const timetable = await post("/v1/extract/timetable", timetableRequest);
if (!validateTimetable(timetable.data)) throw new Error("Timetable extraction did not match the Flutter response schema.");
const timetableReplay = await post("/v1/extract/timetable", timetableRequest, timetable.idempotencyKey);
if (JSON.stringify(timetableReplay.data) !== JSON.stringify(timetable.data)) throw new Error("Timetable idempotent replay returned a different result.");
console.log("Live timetable extraction and idempotent replay passed:", timetable.data.entries.length, "validated classes.");

const examBytes = await readFile(examPath);
const examRequest = {
  document: { mimeType: mimeFor(examPath), data: examBytes.toString("base64") },
  program, semester, section,
};
const exams = await post("/v1/extract/exam", examRequest);
if (!validateExams(exams.data)) throw new Error("Exam extraction did not match the Flutter response schema.");
const examReplay = await post("/v1/extract/exam", examRequest, exams.idempotencyKey);
if (JSON.stringify(examReplay.data) !== JSON.stringify(exams.data)) throw new Error("Exam idempotent replay returned a different result.");
console.log("Live exam extraction and idempotent replay passed:", exams.data.exams.length, "validated exams.");
console.log("Four legitimate requests completed without timeout or rate-limit errors.");
