import { describe, expect, it } from "vitest";
import {
  computeCognitiveProfile,
  type ScoredSession,
} from "@/lib/insights/cognitive-score";

function s(
  moduleKey: string,
  accuracy: number | null,
  medianDecisionMs: number | null,
  startedAt = "2026-07-21T09:00:00Z"
): ScoredSession {
  return { moduleKey, accuracy, medianDecisionMs, reactionMs: null, hesitationCount: null, startedAt };
}

describe("computeCognitiveProfile", () => {
  it("returns nulls with no sessions", () => {
    const p = computeCognitiveProfile([]);
    expect(p.overall).toBeNull();
    expect(p.domains.workingMemory).toBeNull();
    expect(p.confidence).toBe("low");
    expect(p.trend).toBe("insufficient");
  });

  it("maps modules to the right cognitive domains", () => {
    const p = computeCognitiveProfile([
      s("memory_recall", 0.9, 1000),
      s("attention_focus", 0.8, 1000),
      s("math_speed", 0.7, 1000),
      s("pattern_recognition", 0.6, 1000),
    ]);
    expect(p.domains.workingMemory).not.toBeNull();
    expect(p.domains.attention).not.toBeNull();
    expect(p.domains.processingSpeed).not.toBeNull();
    expect(p.domains.reasoning).not.toBeNull();
  });

  it("scores perfect fast sessions near 100", () => {
    const p = computeCognitiveProfile([s("memory_recall", 1.0, 800)]);
    expect(p.domains.workingMemory).toBe(100);
  });

  it("weights speed more heavily for processing speed", () => {
    // Same accuracy, slow: processing speed should score lower than a
    // non-speed domain with identical inputs.
    const slowMath = computeCognitiveProfile([s("math_speed", 1.0, 8000)]);
    const slowMemory = computeCognitiveProfile([s("memory_recall", 1.0, 8000)]);
    expect(slowMath.domains.processingSpeed!).toBeLessThan(
      slowMemory.domains.workingMemory!
    );
  });

  it("detects an improving trend", () => {
    const p = computeCognitiveProfile([
      s("memory_recall", 0.5, 4000, "2026-07-01T09:00:00Z"),
      s("memory_recall", 0.55, 4000, "2026-07-02T09:00:00Z"),
      s("memory_recall", 0.85, 2000, "2026-07-03T09:00:00Z"),
      s("memory_recall", 0.9, 1500, "2026-07-04T09:00:00Z"),
    ]);
    expect(p.trend).toBe("improving");
  });

  it("flags strengths and areas to watch", () => {
    const p = computeCognitiveProfile([
      s("memory_recall", 0.95, 900), // high → strength
      s("pattern_recognition", 0.4, 6000), // low → area to watch
    ]);
    expect(p.strengths).toContain("workingMemory");
    expect(p.areasToWatch).toContain("reasoning");
  });

  it("confidence scales with session volume", () => {
    const one = computeCognitiveProfile([s("memory_recall", 0.8, 2000)]);
    const many = computeCognitiveProfile(
      Array.from({ length: 12 }, () => s("memory_recall", 0.8, 2000))
    );
    expect(one.confidence).toBe("low");
    expect(many.confidence).toBe("high");
  });

  it("ignores modules with no domain mapping", () => {
    const p = computeCognitiveProfile([s("unknown_module", 0.9, 1000)]);
    expect(p.overall).toBeNull();
    expect(p.sessionCount).toBe(1);
  });
});
