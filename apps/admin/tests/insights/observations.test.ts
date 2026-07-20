import { describe, expect, it } from "vitest";
import {
  observeModule,
  type SessionPoint,
} from "@/lib/insights/observations";

function point(
  accuracy: number | null,
  medianDecisionMs: number | null = null,
  hesitationCount: number | null = null
): SessionPoint {
  return { startedAt: "2026-07-20T09:00:00Z", accuracy, medianDecisionMs, hesitationCount };
}

describe("observeModule", () => {
  it("asks for more sessions below the minimum", () => {
    const obs = observeModule("Memory Recall", [point(0.5), point(0.6)]);
    expect(obs).toHaveLength(1);
    expect(obs[0].kind).toBe("neutral");
    expect(obs[0].text).toContain("Not enough Memory Recall sessions");
  });

  it("reports improving accuracy", () => {
    const obs = observeModule("Memory Recall", [
      point(0.5),
      point(0.55),
      point(0.7),
      point(0.8),
    ]);
    expect(
      obs.some(
        (o) =>
          o.kind === "positive" &&
          o.text === "Memory Recall accuracy improved across the last 4 sessions."
      )
    ).toBe(true);
  });

  it("flags an accuracy dip for attention, never as a verdict", () => {
    const obs = observeModule("Mathematics Speed", [
      point(0.9),
      point(0.85),
      point(0.6),
      point(0.55),
    ]);
    const dip = obs.find((o) => o.kind === "attention");
    expect(dip?.text).toContain("dipped");
    expect(dip?.text).toContain("worth revisiting together");
  });

  it("celebrates steady accuracy with faster decisions", () => {
    const obs = observeModule("Mathematics Speed", [
      point(0.8, 2000),
      point(0.82, 1900),
      point(0.81, 1500),
      point(0.8, 1400),
    ]);
    expect(
      obs.some(
        (o) =>
          o.kind === "positive" &&
          o.text.includes("stayed steady while decisions got faster")
      )
    ).toBe(true);
  });

  it("notices decreasing hesitation", () => {
    const obs = observeModule("Memory Recall", [
      point(0.7, 1000, 3),
      point(0.7, 1000, 2),
      point(0.72, 1000, 0),
      point(0.7, 1000, 0),
    ]);
    expect(
      obs.some((o) => o.text.includes("Hesitation during Memory Recall decreased"))
    ).toBe(true);
  });

  it("notices decision-speed consistency", () => {
    const obs = observeModule("Memory Recall", [
      point(0.7, 500),
      point(0.7, 2500),
      point(0.7, 1400),
      point(0.7, 1500),
    ]);
    expect(
      obs.some((o) => o.text.includes("noticeably more consistent"))
    ).toBe(true);
  });

  it("always says something (no empty reports)", () => {
    const obs = observeModule("Memory Recall", [
      point(null, null, null),
      point(null, null, null),
      point(null, null, null),
    ]);
    expect(obs.length).toBeGreaterThan(0);
  });

  it("never uses diagnostic vocabulary", () => {
    const all = [
      ...observeModule("Memory Recall", [point(0.5), point(0.6), point(0.9), point(0.95)]),
      ...observeModule("Memory Recall", [point(0.9), point(0.8), point(0.5), point(0.4)]),
      ...observeModule("Memory Recall", [point(0.7), point(0.7)]),
    ];
    const banned = /diagnos|disorder|deficit|adhd|iq|clinical|impair/i;
    for (const o of all) {
      expect(o.text).not.toMatch(banned);
    }
  });
});
