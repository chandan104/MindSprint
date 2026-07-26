import { describe, expect, it } from "vitest";
import {
  computeReliability,
  type ReliabilityEvent,
} from "@/lib/insights/reliability";

// A clean 3-response session: stimulus → response with human-plausible gaps.
function cleanEvents(): ReliabilityEvent[] {
  return [
    { event_type: "session_started", t_ms: 0 },
    { event_type: "question_displayed", t_ms: 500 },
    { event_type: "tap_registered", t_ms: 1200 },
    { event_type: "question_displayed", t_ms: 2000 },
    { event_type: "tap_registered", t_ms: 2900 },
    { event_type: "question_displayed", t_ms: 3500 },
    { event_type: "tap_registered", t_ms: 4300 },
    { event_type: "session_completed", t_ms: 4600 },
  ];
}

describe("computeReliability", () => {
  it("scores a clean completed session as high with no warnings", () => {
    const r = computeReliability({
      status: "validated",
      wasInterrupted: false,
      events: cleanEvents(),
    });
    expect(r.score).toBe(100);
    expect(r.level).toBe("high");
    expect(r.flags.every((f) => f.severity === "info")).toBe(true);
  });

  it("deducts and flags for app backgrounding", () => {
    const events = cleanEvents();
    events.push({ event_type: "app_backgrounded", t_ms: 2100 });
    events.push({ event_type: "app_foregrounded", t_ms: 2200 });
    const r = computeReliability({
      status: "validated",
      wasInterrupted: true,
      events,
    });
    expect(r.score).toBeLessThan(90);
    expect(r.flags.some((f) => /backgrounded/i.test(f.label))).toBe(true);
  });

  it("flags rapid sub-human responses as random tapping", () => {
    const events: ReliabilityEvent[] = [
      { event_type: "session_started", t_ms: 0 },
    ];
    // 6 stimulus/response pairs, each answered in 100ms (impossible).
    for (let i = 0; i < 6; i++) {
      events.push({ event_type: "question_displayed", t_ms: i * 1000 });
      events.push({ event_type: "tap_registered", t_ms: i * 1000 + 100 });
    }
    events.push({ event_type: "session_completed", t_ms: 6000 });
    const r = computeReliability({
      status: "validated",
      wasInterrupted: false,
      events,
    });
    expect(r.level).not.toBe("high");
    expect(r.flags.some((f) => /sub-human|rapid/i.test(f.label))).toBe(true);
  });

  it("flags a long mid-session pause", () => {
    const events: ReliabilityEvent[] = [
      { event_type: "session_started", t_ms: 0 },
      { event_type: "question_displayed", t_ms: 500 },
      { event_type: "tap_registered", t_ms: 1200 },
      { event_type: "question_displayed", t_ms: 2000 },
      // 90s stare before answering.
      { event_type: "tap_registered", t_ms: 92000 },
      { event_type: "session_completed", t_ms: 92500 },
    ];
    const r = computeReliability({
      status: "validated",
      wasInterrupted: false,
      events,
    });
    expect(r.flags.some((f) => /pause/i.test(f.label))).toBe(true);
  });

  it("flags aborted and invalid sessions", () => {
    const aborted = computeReliability({
      status: "aborted",
      wasInterrupted: false,
      events: [
        { event_type: "session_started", t_ms: 0 },
        { event_type: "session_aborted", t_ms: 1000 },
      ],
    });
    expect(aborted.flags.some((f) => /not completed/i.test(f.label))).toBe(true);
    expect(aborted.score).toBeLessThan(85);
  });

  it("never returns a score outside 0..100", () => {
    const events: ReliabilityEvent[] = [
      { event_type: "session_started", t_ms: 0 },
    ];
    for (let i = 0; i < 10; i++) {
      events.push({ event_type: "app_backgrounded", t_ms: i * 10 });
      events.push({ event_type: "app_foregrounded", t_ms: i * 10 + 5 });
      events.push({ event_type: "question_displayed", t_ms: i * 100 });
      events.push({ event_type: "tap_registered", t_ms: i * 100 + 10 });
    }
    const r = computeReliability({
      status: "invalid",
      wasInterrupted: true,
      events,
    });
    expect(r.score).toBeGreaterThanOrEqual(0);
    expect(r.score).toBeLessThanOrEqual(100);
    expect(r.level).toBe("low");
  });
});
