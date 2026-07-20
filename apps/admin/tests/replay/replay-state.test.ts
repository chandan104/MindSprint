import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  deriveReplayState,
  type ReplayEvent,
} from "@/lib/replay/replay-state";

// The shared contract fixture — the same events both metric engines are
// verified against. Replay must reconstruct this session faithfully.
const fixture = JSON.parse(
  readFileSync(
    join(
      __dirname,
      "../../../../packages/contracts/fixtures/memory_recall_basic.json"
    ),
    "utf8"
  )
) as { events: { seq: number; t_ms: number; event_type: string; payload: Record<string, unknown> }[] };

const events: ReplayEvent[] = fixture.events;

describe("deriveReplayState (memory recall fixture)", () => {
  it("is idle before anything happens", () => {
    const state = deriveReplayState(events, -1);
    expect(state.phase).toBe("idle");
  });

  it("shows exposure with progressive reveal", () => {
    const atFirstItem = deriveReplayState(events, 600);
    expect(atFirstItem.phase).toBe("exposure");
    expect(atFirstItem.sequence.map((s) => s.label)).toEqual([
      "Cat",
      "Dog",
      "Lion",
    ]);
    expect(atFirstItem.revealedCount).toBe(1);

    const atThirdItem = deriveReplayState(events, 4400);
    expect(atThirdItem.revealedCount).toBe(3);
  });

  it("enters recall after sequence_hidden with no taps yet", () => {
    const state = deriveReplayState(events, 6000);
    expect(state.phase).toBe("recall");
    expect(state.taps).toHaveLength(0);
    expect(state.matchedIds).toHaveLength(0);
  });

  it("tracks taps and matched slots, including the wrong tap", () => {
    const afterWrongTap = deriveReplayState(events, 8500);
    expect(afterWrongTap.taps).toHaveLength(2);
    expect(afterWrongTap.taps[1].isCorrect).toBe(false);
    expect(afterWrongTap.matchedIds).toEqual(["cat"]);

    const afterAll = deriveReplayState(events, 10200);
    expect(afterAll.matchedIds).toEqual(["cat", "dog", "lion"]);
  });

  it("reaches complete at the end", () => {
    const state = deriveReplayState(events, 10650);
    expect(state.phase).toBe("complete");
  });

  it("does not flag hesitation for gaps under the threshold", () => {
    // Largest fixture gap is 1442ms.
    const state = deriveReplayState(events, 8400);
    expect(state.isHesitating).toBe(false);
  });

  it("flags hesitation when the clock sits >3000ms after the last input", () => {
    // Freeze time just before the first tap: last input mark is
    // sequence_hidden at 5820; 9000 - 5820 > 3000.
    const truncated = events.filter((e) => e.t_ms <= 5820);
    const state = deriveReplayState(truncated, 9000);
    expect(state.phase).toBe("recall");
    expect(state.isHesitating).toBe(true);
  });
});

describe("deriveReplayState (attention fixture)", () => {
  const attentionFixture = JSON.parse(
    readFileSync(
      join(
        __dirname,
        "../../../../packages/contracts/fixtures/attention_focus_basic.json"
      ),
      "utf8"
    )
  ) as { events: ReplayEvent[] };
  const attention = attentionFixture.events;

  it("shows each stream stimulus with its target flag", () => {
    const onFirst = deriveReplayState(attention, 600);
    expect(onFirst.phase).toBe("stimulus");
    expect(onFirst.currentStimulus).toEqual({ label: "Cat", isTarget: true });
    expect(onFirst.taps).toHaveLength(0);

    const onDistractor = deriveReplayState(attention, 2600);
    expect(onDistractor.currentStimulus).toEqual({
      label: "Dog",
      isTarget: false,
    });
  });

  it("captures the hit and the commission error", () => {
    const afterHit = deriveReplayState(attention, 1200);
    expect(afterHit.taps).toHaveLength(1);
    expect(afterHit.taps[0].isCorrect).toBe(true);

    const afterCommission = deriveReplayState(attention, 7100);
    expect(afterCommission.currentStimulus?.label).toBe("Lion");
    expect(afterCommission.taps[0].isCorrect).toBe(false);
  });

  it("resets taps per stimulus so old taps never bleed forward", () => {
    const nextStimulus = deriveReplayState(attention, 2600);
    expect(nextStimulus.taps).toHaveLength(0);
  });

  it("completes at the end", () => {
    expect(deriveReplayState(attention, 12000).phase).toBe("complete");
  });
});

describe("deriveReplayState (math-style events)", () => {
  const mathEvents: ReplayEvent[] = [
    { seq: 1, t_ms: 0, event_type: "session_started", payload: {} },
    {
      seq: 2,
      t_ms: 500,
      event_type: "question_displayed",
      payload: {
        question_text: "7 + 5",
        expected_answer: "12",
        options: [
          { item_id: "12", label: "12" },
          { item_id: "11", label: "11" },
        ],
      },
    },
    {
      seq: 3,
      t_ms: 2200,
      event_type: "tap_registered",
      payload: { target_kind: "choice", item_id: "12", label: "12", is_correct: true, x: 1, y: 2 },
    },
    { seq: 4, t_ms: 2900, event_type: "session_completed", payload: {} },
  ];

  it("reconstructs the question and the tapped answer", () => {
    const during = deriveReplayState(mathEvents, 1000);
    expect(during.phase).toBe("question");
    expect(during.question?.text).toBe("7 + 5");
    expect(during.question?.options).toHaveLength(2);
    expect(during.taps).toHaveLength(0);

    const afterTap = deriveReplayState(mathEvents, 2300);
    expect(afterTap.taps).toHaveLength(1);
    expect(afterTap.taps[0].isCorrect).toBe(true);
  });

  it("aborted sessions surface the reason", () => {
    const aborted: ReplayEvent[] = [
      ...mathEvents.slice(0, 3),
      {
        seq: 4,
        t_ms: 3000,
        event_type: "session_aborted",
        payload: { reason: "teacher_exit" },
      },
    ];
    const state = deriveReplayState(aborted, 3000);
    expect(state.phase).toBe("aborted");
    expect(state.abortReason).toBe("teacher_exit");
  });
});
