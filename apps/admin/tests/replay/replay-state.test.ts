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

describe("deriveReplayState (visual_search fixture)", () => {
  const vsFixture = JSON.parse(
    readFileSync(
      join(
        __dirname,
        "../../../../packages/contracts/fixtures/visual_search_basic.json"
      ),
      "utf8"
    )
  ) as { events: ReplayEvent[] };
  const vs = vsFixture.events;

  it("reconstructs a target-present trial as a question phase", () => {
    const state = deriveReplayState(vs, 500);
    expect(state.phase).toBe("question");
    expect(state.question?.expectedAnswer).toBe("Cat");
    expect(state.question?.options).toHaveLength(7);
  });

  it("captures the correct find and the correct not-here tap", () => {
    const afterFind = deriveReplayState(vs, 900);
    expect(afterFind.taps).toHaveLength(1);
    expect(afterFind.taps[0].isCorrect).toBe(true);

    const secondTrial = deriveReplayState(vs, 1400);
    expect(secondTrial.question?.expectedAnswer).toBe("not_present");
    expect(secondTrial.taps).toHaveLength(0);
  });

  it("completes at the end", () => {
    expect(deriveReplayState(vs, 23200).phase).toBe("complete");
  });
});

describe("deriveReplayState (sequence_logic fixture)", () => {
  const slFixture = JSON.parse(
    readFileSync(
      join(
        __dirname,
        "../../../../packages/contracts/fixtures/sequence_logic_basic.json"
      ),
      "utf8"
    )
  ) as { events: ReplayEvent[] };
  const sl = slFixture.events;

  it("reconstructs a next-in-series question with its shown run", () => {
    const state = deriveReplayState(sl, 500);
    expect(state.phase).toBe("question");
    expect(state.question?.expectedAnswer).toBe("8");
    expect(state.question?.options).toHaveLength(3);
  });

  it("captures the correct answer then resets for the next question", () => {
    const afterCorrect = deriveReplayState(sl, 2100);
    expect(afterCorrect.taps).toHaveLength(1);
    expect(afterCorrect.taps[0].isCorrect).toBe(true);

    const secondQuestion = deriveReplayState(sl, 3100);
    expect(secondQuestion.question?.expectedAnswer).toBe("20");
    expect(secondQuestion.taps).toHaveLength(0);
  });

  it("completes at the end", () => {
    expect(deriveReplayState(sl, 21200).phase).toBe("complete");
  });
});

describe("deriveReplayState (color_selector fixture)", () => {
  const csFixture = JSON.parse(
    readFileSync(
      join(
        __dirname,
        "../../../../packages/contracts/fixtures/color_selector_basic.json"
      ),
      "utf8"
    )
  ) as { events: ReplayEvent[] };
  const cs = csFixture.events;

  it("shows the animated instruction before the grid appears", () => {
    const reading = deriveReplayState(cs, 600);
    expect(reading.phase).toBe("instruction");
    expect(reading.instructionText).toBe("Tap the RED colour");
    expect(reading.question).toBeNull();
  });

  it("advances to the question with options once the grid is shown", () => {
    const grid = deriveReplayState(cs, 1600);
    expect(grid.phase).toBe("question");
    expect(grid.question?.expectedAnswer).toBe("red");
    expect(grid.instructionText).toBe("Tap the RED colour");
    expect(grid.taps).toHaveLength(0);
  });

  it("captures the correct tap then the later wrong tap", () => {
    const afterCorrect = deriveReplayState(cs, 2500);
    expect(afterCorrect.taps).toHaveLength(1);
    expect(afterCorrect.taps[0].isCorrect).toBe(true);

    const secondRound = deriveReplayState(cs, 9100);
    expect(secondRound.instructionText).toBe("Tap the BLUE colour");
    expect(secondRound.taps[0].isCorrect).toBe(false);
  });

  it("completes at the end", () => {
    expect(deriveReplayState(cs, 21100).phase).toBe("complete");
  });

  it("exposes Stroop congruency when the trial is tagged", () => {
    const stroop: ReplayEvent[] = [
      { seq: 1, t_ms: 0, event_type: "session_started", payload: {} },
      {
        seq: 2,
        t_ms: 300,
        event_type: "instruction_shown",
        payload: { instruction_text: "Tap the WORD Green", instruction_kind: "word" },
      },
      {
        seq: 3,
        t_ms: 1500,
        event_type: "question_displayed",
        payload: {
          question_text: "Tap the WORD Green",
          expected_answer: "green",
          congruent: false,
          options: [{ item_id: "green", label: "Green" }],
        },
      },
    ];
    const state = deriveReplayState(stroop, 1600);
    expect(state.phase).toBe("question");
    expect(state.congruent).toBe(false);
  });
});

describe("deriveReplayState (pattern puzzle with an interior blank)", () => {
  const pattern: ReplayEvent[] = [
    { seq: 1, t_ms: 0, event_type: "session_started", payload: {} },
    {
      seq: 2,
      t_ms: 500,
      event_type: "question_displayed",
      payload: {
        question_text: "Which picture completes the pattern?",
        expected_answer: "Square",
        // Shown row is the full sequence minus the blank; blank_index is the
        // gap's position in the FULL row (here interior, position 2).
        sequence: [
          { item_id: "circle", label: "Circle" },
          { item_id: "square", label: "Square" },
          { item_id: "square", label: "Square" },
        ],
        blank_index: 2,
        options: [
          { item_id: "square", label: "Square" },
          { item_id: "circle", label: "Circle" },
        ],
      },
    },
    {
      seq: 3,
      t_ms: 1800,
      event_type: "tap_registered",
      payload: { target_kind: "choice", item_id: "square", label: "Square", is_correct: true, x: 1, y: 2 },
    },
    { seq: 4, t_ms: 2400, event_type: "session_completed", payload: {} },
  ];

  it("reconstructs the shown row and the interior blank position", () => {
    const state = deriveReplayState(pattern, 1000);
    expect(state.phase).toBe("question");
    expect(state.blankIndex).toBe(2);
    expect(state.sequence).toHaveLength(3);
    expect(state.revealedCount).toBe(3);
    expect(state.question?.expectedAnswer).toBe("Square");
  });

  it("clears the blank for modules that carry no sequence", () => {
    const noSeq: ReplayEvent[] = [
      { seq: 1, t_ms: 0, event_type: "session_started", payload: {} },
      {
        seq: 2,
        t_ms: 500,
        event_type: "question_displayed",
        payload: {
          question_text: "7 + 5",
          expected_answer: "12",
          options: [{ item_id: "12", label: "12" }],
        },
      },
    ];
    expect(deriveReplayState(noSeq, 600).blankIndex).toBeNull();
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
