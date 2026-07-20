// Replay state derivation: a pure fold over the event log up to a virtual
// clock time. No side effects, no timers — the player UI animates the clock,
// this function answers "what was on the child's screen at t?". Being pure
// makes replay exactly reproducible and unit-testable, and it consumes ONLY
// event payloads (never content tables), per ADR-009.

export type ReplayEvent = {
  seq: number;
  event_type: string;
  t_ms: number;
  payload: Record<string, unknown>;
};

export type ReplayTap = {
  itemId?: string;
  label?: string;
  isCorrect?: boolean;
  x?: number;
  y?: number;
  tMs: number;
};

export type ReplayState = {
  phase: "idle" | "exposure" | "recall" | "question" | "complete" | "aborted";
  roundNumber: number;
  /** Sequence announced for the current round (memory modules). */
  sequence: { itemId: string; label: string }[];
  /** How many of the sequence items have been revealed so far. */
  revealedCount: number;
  /** Taps since the current answer phase began. */
  taps: ReplayTap[];
  /** Item ids correctly matched so far in the current round. */
  matchedIds: string[];
  /** Current question (math-style modules). */
  question: {
    text: string;
    expectedAnswer: string;
    options: { itemId: string; label: string }[];
  } | null;
  /** True when >3000ms have passed in an answer phase with no input. */
  isHesitating: boolean;
  lastEventType: string | null;
  abortReason: string | null;
};

const HESITATION_MS = 3000;

const initialState: ReplayState = {
  phase: "idle",
  roundNumber: 0,
  sequence: [],
  revealedCount: 0,
  taps: [],
  matchedIds: [],
  question: null,
  isHesitating: false,
  lastEventType: null,
  abortReason: null,
};

function asItems(value: unknown): { itemId: string; label: string }[] {
  if (!Array.isArray(value)) return [];
  return value.map((entry) => {
    const record = entry as Record<string, unknown>;
    return {
      itemId: String(record["item_id"] ?? ""),
      label: String(record["label"] ?? ""),
    };
  });
}

export function deriveReplayState(
  events: ReplayEvent[],
  tMs: number
): ReplayState {
  const state: ReplayState = { ...initialState, sequence: [], taps: [], matchedIds: [] };
  let lastInputMarkMs = 0;

  const visible = events
    .filter((event) => event.t_ms <= tMs)
    .sort((a, b) => a.seq - b.seq);

  for (const event of visible) {
    state.lastEventType = event.event_type;
    switch (event.event_type) {
      case "sequence_display_started":
        state.roundNumber += 1;
        state.sequence = asItems(event.payload["sequence"]);
        state.revealedCount = 0;
        state.taps = [];
        state.matchedIds = [];
        state.phase = "exposure";
        break;
      case "item_displayed":
        state.revealedCount += 1;
        break;
      case "sequence_hidden":
        state.phase = "recall";
        lastInputMarkMs = event.t_ms;
        break;
      case "question_displayed":
        state.roundNumber += 1;
        state.question = {
          text: String(event.payload["question_text"] ?? ""),
          expectedAnswer: String(event.payload["expected_answer"] ?? ""),
          options: asItems(event.payload["options"]),
        };
        state.taps = [];
        state.phase = "question";
        lastInputMarkMs = event.t_ms;
        break;
      case "tap_registered": {
        const tap: ReplayTap = {
          itemId: event.payload["item_id"] as string | undefined,
          label: event.payload["label"] as string | undefined,
          isCorrect: event.payload["is_correct"] as boolean | undefined,
          x: event.payload["x"] as number | undefined,
          y: event.payload["y"] as number | undefined,
          tMs: event.t_ms,
        };
        state.taps = [...state.taps, tap];
        if (tap.isCorrect && tap.itemId) {
          state.matchedIds = [...state.matchedIds, tap.itemId];
        }
        lastInputMarkMs = event.t_ms;
        break;
      }
      case "answer_submitted":
        lastInputMarkMs = event.t_ms;
        break;
      case "session_completed":
        state.phase = "complete";
        break;
      case "session_aborted":
        state.phase = "aborted";
        state.abortReason =
          (event.payload["reason"] as string | undefined) ?? null;
        break;
      default:
        break;
    }
  }

  state.isHesitating =
    (state.phase === "recall" || state.phase === "question") &&
    tMs - lastInputMarkMs > HESITATION_MS;

  return state;
}
