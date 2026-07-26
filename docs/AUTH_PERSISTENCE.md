# Persistent Login (pilot blocker fix)

## Root cause

The Supabase session **was** already persisted to disk and silently refreshed by
`supabase_flutter` (its defaults). The bug was that the app **never restored it**:

- The router's `initialLocation` was `/login`, with **no auth redirect**.
- `LoginScreen` never checked `currentSession`; it only navigated onward *after*
  an explicit `signIn()`.
- `startupStateProvider` (version gate + feature flags) was populated **only**
  inside `signIn()`, so even a valid restored session had no path to the roster.

Net effect: every app reopen showed the login form, regardless of a valid stored
session. It was not a token/persistence problem — it was a missing restore path.

## Fix

- **Splash route** (`/`, now `initialLocation`) restores the session before any
  UI. Shows a brief "Restoring session…" loader instead of flashing login.
- **`AuthController.restore()`** — the single restore decision:
  - no persisted session → **login**
  - `AuthException` (refresh token invalid / account revoked) → sign out → **login**
  - `VersionBlockedFailure` (outdated client) → sign out → **login** (with message)
  - success → run the version+flags gate, cache flags, → **roster**
  - any other error (offline/transient) → reopen into the **roster** with
    last-known cached flags; version + flags re-check on the next online launch
- **`FeatureFlagsCache`** (secure storage) persists the last flags so offline
  reopen has a usable roster.
- `Supabase.initialize` now sets `authOptions` (`pkce`, `autoRefreshToken: true`)
  explicitly — same as the defaults, but pinned against SDK drift.
- Audit confirmed **no stray sign-outs**: the only `signOut()` calls are the
  version-block path and the explicit logout button.

## Requirements → how they're met

| Requirement | Mechanism |
|---|---|
| Stay signed in across restarts | SDK persists session; splash restores it |
| Auto-restore previous session | `restore()` on splash |
| Offline reopen with valid session | `catch` → roster with cached flags (no forced login) |
| Silent token refresh | SDK `autoRefreshToken`; gate call triggers refresh |
| Login only on logout / invalid refresh / revoked | the three explicit branches above |
| Loading screen, not login-flash | `SplashScreen` renders before any decision |

## Device verification matrix (manual, on the APK)

Automated tests cover the decision logic (`test/features/auth/restore_test.dart`)
and that a session-less boot still lands on login (`widget_test.dart`). The
following must be spot-checked on a real Android device with the pilot build:

- [ ] Sign in once, then reopen the app **50×** (close normally) → roster every time, never login.
- [ ] Swipe the app away from recents, reopen → roster.
- [ ] Reboot the phone, open the app → roster.
- [ ] Turn off Wi‑Fi/data, reopen → roster (offline), with cached module list.
- [ ] Install an app update over the top, reopen → roster (unless version-blocked).
- [ ] Leave idle overnight (access token expires), reopen online → roster (silent refresh).
- [ ] Explicit "Sign out" → login on next open.
- [ ] Revoke the user in Supabase, reopen online → login.
