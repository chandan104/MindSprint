import { describe, expect, it } from "vitest";
import {
  moduleAverages,
  monthlyRollup,
  weeklyRollup,
} from "@/lib/insights/rollups";

describe("weeklyRollup", () => {
  it("groups sessions into ISO weeks and averages", () => {
    const r = weeklyRollup([
      { startedAt: "2026-07-20T09:00:00Z", value: 80 }, // W30
      { startedAt: "2026-07-21T09:00:00Z", value: 90 }, // W30
      { startedAt: "2026-07-27T09:00:00Z", value: 60 }, // W31
    ]);
    expect(r).toHaveLength(2);
    expect(r[0].value).toBe(85);
    expect(r[1].value).toBe(60);
    expect(r[0].label).toMatch(/^2026-W\d\d$/);
  });

  it("skips null values", () => {
    const r = weeklyRollup([
      { startedAt: "2026-07-20T09:00:00Z", value: null },
      { startedAt: "2026-07-20T10:00:00Z", value: 50 },
    ]);
    expect(r[0].value).toBe(50);
  });
});

describe("monthlyRollup", () => {
  it("groups by calendar month, sorted", () => {
    const r = monthlyRollup([
      { startedAt: "2026-06-15T09:00:00Z", value: 70 },
      { startedAt: "2026-07-01T09:00:00Z", value: 80 },
      { startedAt: "2026-07-31T09:00:00Z", value: 90 },
    ]);
    expect(r.map((p) => p.label)).toEqual(["2026-06", "2026-07"]);
    expect(r[1].value).toBe(85);
  });
});

describe("moduleAverages", () => {
  it("averages accuracy per module and counts sessions", () => {
    const r = moduleAverages([
      { moduleKey: "memory_recall", accuracy: 0.8 },
      { moduleKey: "memory_recall", accuracy: 1.0 },
      { moduleKey: "math_speed", accuracy: 0.5 },
      { moduleKey: "math_speed", accuracy: null },
    ]);
    const mem = r.find((m) => m.moduleKey === "memory_recall")!;
    const math = r.find((m) => m.moduleKey === "math_speed")!;
    expect(mem.avgAccuracy).toBe(90);
    expect(mem.sessions).toBe(2);
    expect(math.avgAccuracy).toBe(50);
    expect(math.sessions).toBe(2); // counts the null-accuracy session too
  });
});
