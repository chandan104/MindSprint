# Metric definitions — v1

Operational definitions for MindSprint. These are project definitions for
educational comparison, not clinical standards. Both the Dart provisional
engine and the SQL canonical engine implement exactly these; CI runs shared
fixtures against both and fails on any disagreement.

All times derive from event `t_ms` (monotonic ms since session start).

| Metric | Definition (v1) |
|---|---|
| Reaction time | `t_ms(first tap_registered after stimulus visible)` − `t_ms(stimulus visible)`. Stimulus visible = `sequence_display_started` or `question_displayed`. |
| Recall time | `t_ms(first tap_registered after sequence_hidden)` − `t_ms(sequence_hidden)`. |
| Decision time | Gap between consecutive answer taps within one recall/answer phase. |
| Hesitation | Any inter-tap gap > **3000 ms** within an answer phase (fixed threshold in v1; revisit against pilot data). Count and total duration both reported. |
| Total time | `t_ms(session_completed)` − `t_ms(session_started)`. |
| Pause time | Sum of `pause_ended.t_ms − pause_started.t_ms` pairs. |
| Idle time | Sum of hesitation gap durations. |
| Accuracy | correct answers ÷ total answers (from `answer_submitted.is_correct` / `tap_registered.is_correct`). |
| Error count | Count of incorrect answers. |
| Mean / median / fastest / slowest reaction | Over all per-stimulus reaction times in the session. |
| Longest pause | Max single inter-tap gap. |
| Consistency | Population standard deviation of reaction times. |
| Fatigue trend | Least-squares slope of reaction time vs. trial index within the session (positive = slowing). |
| Learning rate | Across sessions of the same level: slope of accuracy vs. session index. Computed server-side only (needs history). |

Interruption rule: any session containing `app_backgrounded` is flagged
`was_interrupted`; reaction metrics spanning the interruption are excluded
from benchmarks.
