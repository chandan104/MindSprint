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

### #4 Sequence Logic — more than one rule, fewer lucky guesses
**Problem:** every "kind" reduced to a **constant arithmetic step** (a single
construct any child solves by spotting the difference); `arrange_order` was
functionally identical to `next_in_series`. Only **3 options** (33% guess floor)
and the internal rule name leaked into the prompt.

**Fix (generator + prompt):**
- New rule families the child must actually infer: **geometric** (×2/×3),
  **fibonacci** (sum of previous two), **alternating** (two interleaved steps),
  alongside the existing arithmetic ascending/descending.
- **4 options** (guess floor 33% → 25%); distractors are rule-relevant errors
  (counted one term too far, repeated the previous term, wrongly assumed a
  constant step).
- Prompt no longer names the rule ("What comes next?").
- `logic_kinds` enum extended (contract-additive). New **Extreme** level
  (migration `…005` + seed) uses the non-linear families.

**Drift guards:** the `sequence_logic_basic.json` fixture is a static arithmetic
run — still validates; no metric change.

⚠ **interpretation:** post-change accuracy reflects multi-rule reasoning and a
25% (not 33%) guess floor; not directly comparable to pre-change scores.

### #5 Memory Recall — measures memory, not persistence
**Problem:** recall was self-paced with **unlimited free retries** — a wrong tap
only flashed and the child kept guessing until right, so the round always ended
with every slot correct and "accuracy" really measured *how many wrong guesses
before brute-forcing it*, i.e. persistence, not recall.

**Fix (gameplay — the metric formula is unchanged, so both engines and every
prior fixture are byte-for-byte stable):**
- **First tap per slot is the scored response.** A wrong first tap is recorded
  as that slot's error, the correct item is revealed, and the round advances —
  no re-attempts. `correct_count / sequence_length` is now a true recall
  accuracy (partial credit per position).
- **Optional recall timeout** (`recall_time_limit_ms`, additive/null-safe):
  when set, remaining slots are scored as misses on expiry, bounding a stuck
  child's persistence. Omitted = self-paced (young/Easy tiers).
- Errored slots are tinted so a miss is visible in-play; the correct item is
  still shown (good pedagogy).

**Why no metric-engine change:** the shared `accuracy = correct/(correct+error)`
already does the right thing once the *data* carries one scored response per
slot. New fixture `memory_recall_firsttap.json` + pgTAP `14` lock this in on
both engines; the original `memory_recall_basic.json` (retry-style events) still
reproduces exactly — proving backward compatibility.

**Not retrofitted:** `recall_time_limit_ms` is left off existing hosted levels
on purpose — `level_versions` are immutable and retrofitting would rewrite the
meaning of past sessions. It is opt-in for future/new levels.

⚠ **interpretation:** Memory Recall accuracy will typically **fall** versus
history (brute-force retries no longer inflate it) and now reflects genuine
recall. Historical trend lines cross a break at this change.

**Follow-up (deferred):** adaptive span (grow the sequence until the child
fails) would turn accuracy into a true span estimate — a larger redesign.

### #6 Focus Tap — no rhythm, no lucky clusters
**Problem:** a **fixed** inter-stimulus gap let a child fall into a tapping
rhythm and hit targets on beat (reaction time then reflects timing, not
detection); the fully-shuffled plan could place **targets back-to-back**, where
one rhythmic double-tap scores two hits. (The target frequency ramp — rarer
targets at higher tiers — is retained: it is a legitimate *vigilance* load, and
the module's construct is now documented explicitly as sustained selective
attention / vigilance, not a mixed one.)

**Fix (engine defaults — no config mutation, applies to every existing level):**
- **ISI jitter**: each gap is the base ± a random jitter (default 40% of the
  gap, floor 50ms), so stimulus onsets are unpredictable.
- **Anti-clustering**: targets are distributed into the gaps between distractors
  so no two are consecutive (falls back to a shuffle only if targets are too
  dense to separate).
- Optional `inter_stimulus_jitter_ms` knob added (contract-additive).

**Drift guards:** no metric/schema-of-record change — the attention fixture and
both engines are unaffected. New test asserts no back-to-back targets.

⚠ **interpretation:** minor — reaction-time distributions get slightly cleaner
(no rhythmic pre-emption); accuracy semantics are unchanged.

### #7 Colour Selector — controlled congruency + interference metric
**Problem:** every Stroop tile was incongruent (word ≠ ink), so there were no
congruent trials to compare against — the defining Stroop measure (interference)
couldn't be computed. Only 5 rounds gave a noisy estimate.

**Fix:**
- **Controlled congruency:** ~1/3 of Stroop trials are now congruent (target
  word == ink); each `question_displayed` is tagged with `congruent`
  (contract-additive boolean). Round construction guarantees exactly one target
  tile in both word- and colour-instruction modes.
- **New canonical metric `stroop_interference_ms`** = mean reaction time on
  incongruent trials − mean on congruent trials (correct responses only), in
  both engines (Dart provisional + SQL `compute_session_metrics`, migration
  `…006`), additive & null-safe (null unless both trial kinds exist).
- **8 rounds** (was 5) for a more reliable estimate.
- Replay reducer exposes `congruent`; new fixture `color_selector_stroop.json`
  + pgTAP `15` drift-guard the metric (interference = 350 in the fixture).

**Drift guards:** additive/null-safe — `jsonb_strip_nulls` drops the metric for
every non-Stroop session, so all prior fixtures reproduce unchanged.

⚠ **interpretation:** a new metric with no history; accuracy/RT semantics of
existing Colour Selector data are unchanged.

## Status
All seven backlog items (#1–#7) implemented. Systemic follow-ups (#8 audio/icon
prompts for the reading confound; #9 uniform ≥4 options) remain as future
milestones, plus adaptive Memory Recall span and feature-based Visual Search
similarity noted above.
