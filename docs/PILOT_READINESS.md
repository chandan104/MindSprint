# MindSprint Pilot Readiness

The official gate before deployment to a real school. Updated after every
milestone. Legend: ✅ ready · 🟡 partial / needs a pass · ❌ not started ·
⛔ blocking for pilot.

_Last updated: 2026-07-21 (teacher invites + data erasure)._

## Student experience

| Item | Status | Notes |
|---|---|---|
| Four playable modules (Memory, Math, Focus, Pattern) | ✅ | Each with world identity, tutorial card, difficulty tiers, feedback, haptics |
| Result celebration + educational language | ✅ | Star spring-in, effort-focused copy, interruption honesty |
| Kiosk mode (back-trap + teacher PIN) | ✅ | Device-validated |
| Visual Search + Sequence Logic gameplay | ❌ | Reserved modules; not pilot-blocking (flags off) |
| Sound design | ❌ | Haptics shipped; audio needs assets (backlog) |
| Practice/tutorial rounds excluded from metrics | ❌ | Backlog — first-session confusion currently pollutes baselines; consider before pilot |
| Reduced-motion + colorblind pass | 🟡 ⛔ | Shapes labeled by name (good); needs a deliberate audit before children use it |

## Teacher experience

| Item | Status | Notes |
|---|---|---|
| Login, roster, student confirm, assessment setup | ✅ | Device-validated |
| Instant provisional results | ✅ | |
| Session list/detail + canonical metrics | ✅ | |
| Session Replay | ✅ | All four modules reconstruct |
| Student trends + observations | ✅ | Sentence-tested, never-diagnose enforced |
| Teacher notes | ✅ | Append-only, attributed |
| Teacher onboarding without SQL | ✅ | Admin invites by email; teacher self-signs-up and claims via `/join/[token]`; pgTAP 10 |

## Administrator experience

| Item | Status | Notes |
|---|---|---|
| Roster CRUD (schools/classes/teachers/students) | ✅ | Audited mutations |
| Overview with processing/needs-review queues | ✅ | |
| Bulk student import (CSV) | ❌ | Backlog; painful for real class sizes without it |
| Audit log viewer | ❌ | Data recorded since Phase 1; UI pending |
| Data-erasure flow (DPDP) | ✅ | `delete_student` definer RPC (audited, cascading) + typed-confirmation admin UI; pgTAP 09 |
| Benchmarks / class comparisons | ❌ | Needs session volume; post-pilot-start acceptable |

## Measurement integrity

| Item | Status | Notes |
|---|---|---|
| Monotonic timing, immutable events, idempotent upload | ✅ | Device-validated end-to-end |
| Two-engine drift guard (Dart + SQL) | ✅ | All four playable modules have fixtures (memory, attention, pattern; math covered by pattern's shared contract — dedicated math fixture would still be nice) |
| Canonical metrics sweep + failure quarantine | ✅ | pg_cron every minute; invalid → needs-review |
| Interruption honesty (backgrounding taints sessions) | ✅ | |
| Per-question reaction times (metrics v2) | ❌ | Backlog |

## Security & privacy

| Item | Status | Notes |
|---|---|---|
| RLS as the boundary, pgTAP impersonation suites | ✅ | 8 suites in CI |
| No third-party SDKs/ads/analytics in student app | ✅ | |
| Minimal student PII (name, roll, birth year) | ✅ | |
| Secrets hygiene | ✅ | History scanned; exposed credentials rotated when incidents occurred |
| Data-erasure surfaced + retention policy documented | ❌ ⛔ | See administrator section |

## Operations & deployment

| Item | Status | Notes |
|---|---|---|
| CI (Flutter, admin, contracts, pgTAP) | ✅ | Green on every milestone |
| Hosted Supabase migrations in sync | ✅ | 16 migrations |
| Release-signed APK + Play Store listing | ❌ ⛔ | Debug builds only; signing config + store assets needed |
| Name/trademark/Play availability check (rename gate) | ❌ ⛔ | "MindSprint" + com.mindsprint.app still placeholders |
| Admin dashboard hosting (currently local dev only) | ❌ ⛔ | Deploy to Vercel or similar before teachers use it |
| Windows/macOS desktop builds | ❌ | Not pilot-blocking (Android-first) |
| Local Docker (dev loop) | 🟡 | Broken on this machine; CI covers DB testing |
| Crash reporting | ❌ | Evaluate privacy-compatible option |
| Teacher/admin user guide | ❌ | One-pager each before pilot |

## Known issues & risks

- Free-tier Supabase limits are fine for a pilot; watch storage as
  session_events grows (partitioned, prunable by month).
- Retry queue has no size cap (bounded in practice by classroom volume).
- Observation engine thresholds (0.08 accuracy delta, etc.) are engineering
  estimates; revisit against pilot data.
- Emoji visuals render differently across Android versions; acceptable, but
  the media pipeline (real images) is the long-term answer.

## Pilot-blocking summary (the ⛔ list)

1. Release signing + store/distribution path
2. Name rename-gate checks
3. Admin dashboard hosting
4. Accessibility audit (reduced-motion, contrast, colorblind)

Cleared 2026-07-21: teacher onboarding (invite flow), data erasure.
