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

### #2 Pattern Detective — rule-finding, not extrapolation
**Problem:** the blank was **always the final slot**, so the task measured
"predict the next item" rather than "find the rule"; distractors were random
unrelated pool items, so the answer was often the only option that fit the
rhythm (solvable by elimination, not reasoning). `mirror`'s answer was the first
shown item. The internal rule name leaked into the prompt.

**Fix:**
- **Variable blank position** — placed where the rule is still recoverable (a
  full period of context precedes it for periodic kinds; any non-self-mirroring
  slot for palindromes). Forces application of the rule, not last-item copying.
- **Rule-based distractors** — the "repeat the neighbour" naive-continuation
  error plus other wrong-slot motif members are offered before wider-pool
  fillers, so a child cannot win by rhythm/elimination.
- Prompt no longer leaks the rule ("Which picture completes the pattern?").
- New optional `blank_index` on `question_displayed` (contract-additive,
  null-safe). `sequence` remains the shown row (full minus blank).

**Replay:** the reducer now reconstructs the shown row and the blank position on
`question_displayed`; the replayer renders the puzzle with the "?" in place. The
memory-recall rebuild grid is guarded to recall modules (those set no
`question`) so question modules no longer mis-render it.

**Drift guards:** metric engines unaffected (no metric change); the existing
`pattern_recognition_basic.json` fixture (final-blank, no `blank_index`) still
validates — proving backward compatibility.

⚠ **interpretation:** post-change Pattern Detective accuracy reflects genuine
rule induction and is **not directly comparable** to pre-change scores, which
were inflated by the always-final blank and rhythm-solvable distractors. Trend
lines spanning the change should be read with this break in mind.

### #3 Math Speed — distractors model real miscalculations
**Problem:** distractors were uniform ±1..3 near-misses, so options could be
eliminated by rough estimation without computing; multiplication/division had no
error-pattern foils; the division operation (generator-supported) was unused and
there was no Extreme tier.

**Fix (generator-only — no event/metric/fixture change):** distractors are now
the specific wrong answers a child produces by mis-applying the operation —
place-value slip (±10), adjacent times-table rows (`a×(b±1)`, `(a±1)×b`),
off-by-one, and wrong-operation results — padded with near-misses only if that
pool is short. Invariants preserved (answer present once, distinct, ≥0, exactly
`optionCount`). New **Extreme** level (migration `…004`, additive/idempotent):
`mul`+exact-`div`, operands 3–15, 8s clock.

**Drift guards:** untouched (pure generation change). Existing math fixture and
both engines unaffected.

⚠ **interpretation:** Math Speed accuracy at a given level may **drop** versus
history because guessing is now harder — the score is a truer measure of
fact fluency. Reaction/decision-time metrics are unaffected.
