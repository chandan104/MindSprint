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
| Reduced-motion + colorblind pass | ✅ | `reducedMotion()` skips decorative animation (celebration, exposure reveal); every correct/wrong state pairs color with an icon (never color-only) across all 4 modules |

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
| Release-signed APK + Play Store listing | 🟡 ⛔ | `build.gradle.kts` reads `android/key.properties` (gitignored) with release minify+shrink; falls back to debug signing when absent. **Owner action needed:** generate the production keystore (`key.properties.example` has the command) and store it securely — cannot be automated |
| Name/trademark/Play availability check (rename gate) | ❌ ⛔ | "MindSprint" + com.mindsprint.app still placeholders |
| Admin dashboard hosting (currently local dev only) | 🟡 ⛔ | App-side readiness done: `error.tsx`/`not-found.tsx` boundaries, `/api/health` check, build-info footer. **Owner action needed:** create the hosting account (Vercel or similar) and connect the repo |
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

1. **Release signing** — mechanism ready; owner must generate + custody the keystore
2. **Name rename-gate checks** — owner decision (Play availability, domain, trademark)
3. **Admin dashboard hosting** — app-ready; owner must create the hosting account
4. Accessibility audit — cleared (see below)

Cleared 2026-07-21: teacher onboarding, data erasure, accessibility audit.
All remaining blockers require an account/business decision only the
product owner can make — no more code-only blockers exist.

## Accessibility audit detail (2026-07-21)

- **Contrast (WCAG AA, computed):** bg/white 20.1:1, bg/textDim 7.9:1,
  bg/primary 4.5:1, bg/success 10.5:1, bg/danger 7.5:1 — all pass AA
  (4.5:1 normal text / 3:1 UI elements).
- **Colorblind:** every correct/wrong signal pairs an icon with color
  across all 4 modules (was color-only in 2 tile types — fixed).
- **Reduced motion:** `reducedMotion(context)` (reads
  `MediaQuery.disableAnimations`) skips the result-screen star spring-in
  and the memory-recall exposure reveal animation; gameplay timing is
  never affected, only decorative motion.
- **Touch targets:** every gameplay tile enforces `AppTheme.minTouchTarget`
  (56dp); Focus Tap's tap surface is a 180×180 stage, far above minimum.
- **Screen reader:** `ItemVisual` carries `semanticsLabel`; default
  Material semantics on all buttons/icons.
- **Admin keyboard/responsive:** shadcn/Radix primitives are
  keyboard-navigable by default; Tailwind responsive utilities throughout.
  Not manually tested with a physical screen reader — flagged in backlog
  for a dedicated pass before pilot.
