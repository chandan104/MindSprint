# Cognitive Validity & Difficulty Balancing (Objective 3)

Goal: every score should represent the student's **cognitive ability** — not
persistence, luck, memorization, or brute-force guessing. Changes are made
module-by-module, fixture-first, keeping both metric engines (Dart provisional +
SQL canonical) drift-guarded and the event/replay/upload contract stable.

Backward compatibility: additive event/metric fields are null-safe so historical
sessions and existing fixtures reproduce unchanged. Where a change alters how a
score should be *interpreted* over time, it is flagged **⚠ interpretation** below.

## Audit summary (2026-07-26)

| Module | Primary ability | Key weakness found |
|--------|-----------------|--------------------|
| Memory Recall | Working memory, serial order | Self-paced unlimited retries → scores persistence, not span |
| Math Speed | Processing speed, fact fluency | ±1..3 distractors too easy; no miscalculation foils; div unused |
| Focus Tap | Sustained attention, inhibition | Construct drifts across tiers; fixed ISI invites rhythmic tapping |
| Pattern Detective | Inductive reasoning | Blank always final → extrapolation not rule-finding; random foils |
| Visual Search | Selective visual attention | Grid silently shrank to pool size; all-unique = pop-out not search |
| Sequence Logic | Numerical reasoning | Single construct (linear step); kind label leaks; 33% luck floor |
| Colour Selector | Selective attention / Stroop | Congruency ratio uncontrolled; only 5 rounds |

## Change log

### #1 Visual Search — grid now realizes its configured set size
**Problem (bug):** `_buildTrial` took `gridSize - 1` distractors from a category
of only ~8 items, so a Hard grid configured at 25 tiles rendered ~8. Configured
difficulty was never delivered; search RT did not scale with set size.

**Fix:** the grid is filled to its true `grid_size` by sampling distractors
*with repetition* into unique positional cells (`c0…cN`). Exactly one target
cell when present. Event `options` now carry per-cell ids; `expected_answer` is
the target cell id (or `not_present`). Denser grids render more columns.

**Scope:** gameplay/generation only — no event-schema, metric, or fixture change,
so all drift guards are untouched. Not an ⚠ interpretation change (historical
sessions were played on whatever grid actually rendered; new sessions render the
intended grid).

**Follow-up (deferred):** true conjunction search (target–distractor feature
similarity) needs per-item visual-feature metadata the content model lacks.
