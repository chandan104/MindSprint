// Assessment Reliability Score — an ADMIN-ONLY integrity signal about how much
// to trust a session's conditions. It is computed purely from what the session
// recorded (lifecycle events, response timing, completion status) and MUST
// NEVER influence cognitive scores: it answers "were the testing conditions
// clean?", not "how did the child do?". Every deduction maps to a visible flag.

export type ReliabilityFlag = {
  severity: "info" | "warn";
  label: string;
};

export type Reliability = {
  score: number; // 0..100
  level: "high" | "medium" | "low";
  flags: ReliabilityFlag[];
};

export type ReliabilityEvent = {
  event_type: string;
  t_ms: number;
  payload?: Record<string, unknown> | null;
};

export type ReliabilityInput = {
  status: string;
  wasInterrupted: boolean;
  events: ReliabilityEvent[];
};

// A genuine simple reaction can't beat ~250 ms (perception + motor). Responses
// faster than this are anticipation or random tapping, not real decisions.
const HUMAN_RT_FLOOR_MS = 250;
// A gap this long inside an active session means the child stepped away.
const LONG_PAUSE_MS = 60_000;

const STIMULUS_EVENTS = new Set([
  "question_displayed",
  "item_displayed",
  "sequence_hidden",
]);
const RESPONSE_EVENTS = new Set(["tap_registered", "answer_submitted"]);

/** Pure, deterministic. Same session in → same reliability out. */
export function computeReliability(input: ReliabilityInput): Reliability {
  const { events } = input;
  const flags: ReliabilityFlag[] = [];
  let deduction = 0;

  const backgroundings = events.filter(
    (e) => e.event_type === "app_backgrounded"
  ).length;
  const resumes = events.filter(
    (e) => e.event_type === "app_foregrounded"
  ).length;

  if (backgroundings > 0) {
    deduction += Math.min(40, 15 + (backgroundings - 1) * 10);
    flags.push({
      severity: "warn",
      label: `App backgrounded ${backgroundings}×`,
    });
  }
  if (resumes > 1) {
    deduction += Math.min(15, resumes * 5);
    flags.push({ severity: "warn", label: `Multiple resumes (${resumes})` });
  }

  // Pair each response with the most recent stimulus onset to get its reaction
  // time; count implausibly fast responses and the longest idle gap.
  let lastStimulusT: number | null = null;
  let fastResponses = 0;
  let responses = 0;
  let longestGapMs = 0;
  let prevMarkT = events.length ? events[0].t_ms : 0;

  for (const e of [...events].sort((a, b) => a.t_ms - b.t_ms)) {
    if (STIMULUS_EVENTS.has(e.event_type)) lastStimulusT = e.t_ms;
    if (RESPONSE_EVENTS.has(e.event_type)) {
      responses++;
      if (lastStimulusT != null && e.t_ms - lastStimulusT < HUMAN_RT_FLOOR_MS) {
        fastResponses++;
      }
      longestGapMs = Math.max(longestGapMs, e.t_ms - prevMarkT);
      prevMarkT = e.t_ms;
    } else if (STIMULUS_EVENTS.has(e.event_type)) {
      prevMarkT = e.t_ms;
    }
  }

  if (responses >= 4 && fastResponses / responses > 0.3) {
    const pct = Math.round((fastResponses / responses) * 100);
    deduction += Math.min(35, 15 + Math.round((pct - 30) / 3));
    flags.push({
      severity: "warn",
      label: `Rapid, sub-human responses (${pct}% under ${HUMAN_RT_FLOOR_MS}ms)`,
    });
  }

  if (longestGapMs >= LONG_PAUSE_MS) {
    deduction += 10;
    flags.push({
      severity: "warn",
      label: `Long pause mid-session (${Math.round(longestGapMs / 1000)}s)`,
    });
  }

  if (input.wasInterrupted && backgroundings === 0) {
    // Flagged interrupted but no lifecycle event captured it — still surface it.
    deduction += 15;
    flags.push({ severity: "warn", label: "Session marked interrupted" });
  }

  const aborted = events.some((e) => e.event_type === "session_aborted");
  if (aborted || input.status === "aborted") {
    deduction += 20;
    flags.push({ severity: "warn", label: "Session not completed" });
  }
  if (input.status === "invalid") {
    deduction += 25;
    flags.push({ severity: "warn", label: "Metrics computation failed" });
  }

  const score = Math.max(0, Math.min(100, 100 - deduction));
  const level = score >= 85 ? "high" : score >= 60 ? "medium" : "low";

  if (flags.length === 0) {
    flags.push({ severity: "info", label: "Normal reaction pattern" });
    flags.push({ severity: "info", label: "No interruptions" });
    flags.push({ severity: "info", label: "Completed session" });
  }

  return { score, level, flags };
}
