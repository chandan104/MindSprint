# MindSprint

Educational cognitive assessment platform: game-based assessments measure
students' reaction time, recall, decision time, hesitation, accuracy, and
learning progress — educationally, never diagnostically. Free; no ads, no
third-party SDKs.

Start with [docs/PROJECT_SPECIFICATION.md](docs/PROJECT_SPECIFICATION.md),
[docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md), and
[docs/ROADMAP.md](docs/ROADMAP.md).

## Layout

| Path | What |
|---|---|
| `apps/student` | Flutter app (Android APK first; Windows/macOS) — teacher-supervised assessments |
| `apps/admin` | Next.js admin dashboard (SSR auth, RLS-scoped) |
| `supabase/` | Migrations (schema source of truth), seed, pgTAP tests |
| `packages/contracts` | Versioned JSON Schemas: events, level configs, metric definitions + fixtures |
| `tools/` | Contract validator, seed-user instructions |

## Development

Prereqs: Flutter (stable), Node 22+, Docker Desktop, Windows Developer Mode
(for Flutter plugin symlinks). The Supabase CLI is vendored via
`tools-cli/` (`npm i` there) or install your own.

```sh
supabase start          # local stack
supabase db reset       # apply all migrations + seed
supabase test db        # pgTAP: schema, RLS isolation, immutability

cd apps/admin
cp .env.example .env.local   # point at local stack (see supabase start output)
npm ci && npm run dev

cd apps/student
cp env/dev.json.example env/dev.json
flutter pub get
dart run build_runner build
flutter run --dart-define-from-file=env/dev.json
```

Local pilot users: create per `tools/seed-users.md`.

## Non-negotiables

- `session_events` is immutable and partitioned; all metrics/replay derive
  from it (event sourcing — ADR-003).
- Students never have accounts (ADR-004). Minimal student PII only.
- Every permission check reads `user_roles` via JWT claims (ADR-011); the
  pgTAP RLS suite must be extended BEFORE any policy change is trusted.
- Package id `com.mindsprint.app` is a placeholder until the pre-release
  rename gate (Play Store / domain / trademark checks).
