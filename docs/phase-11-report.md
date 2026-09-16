# Phase 11 Report — Login / Register / Profile UI

## 1. Auth state & session lifecycle

`lib/features/auth/presentation/auth_state.dart` — a `ChangeNotifier` that owns
the in-memory session and exposes a four-state `AuthStatus` (unknown /
unauthenticated / refreshing / authenticated):

- `initialise()` runs on app start; with no stored tokens it reports
  `unauthenticated` immediately; with tokens still in memory (e.g. hot restart)
  it re-validates via refresh + `/auth/me`.
- `login()` calls the backend, stores the token pair, loads the caller identity
  via `/auth/me`, and only reaches `authenticated` when that succeeds.
- `register()` calls `/auth/register` and returns to `unauthenticated` so the
  user signs in with their new credentials.
- `logout()` revokes the refresh session server-side (best-effort), then clears
  local state regardless of the outcome.
- `attemptRefresh()` is the single refresh entry point and **serializes
  concurrent callers onto one in-flight rotation** (`_pendingRefresh`), so the
  single-use refresh token is never raced by a parallel 401 wave.
- All errors are translated to user-facing strings (friendly login/register/
  session messages, validation details joined into one banner) via
  `_friendly*Error` — internals, tokens and stack traces are never exposed.

## 2. Token transport — AuthenticatedHttpClient

`lib/features/auth/presentation/auth_http_client.dart` wraps the raw
`http.Client`:

- injects `Authorization: Bearer <accessToken>` on protected paths and leaves
  the public auth paths (`POST /auth/login`, `/auth/register`, `/auth/refresh`,
  `/auth/logout`, `/health`) untouched,
- on a `401` it performs **one** refresh and retries the request once with the
  fresh token, tagging the retry `x-auth-retried: true` (a guard ensures it
  never refreshes twice for the same request),
- when refresh fails it clears the session and returns the original `401`.
- `AuthState`'s own refresh + auth calls use the raw `_http` client, never the
  authenticated transport, so a stale `401` can never re-enter the refresh
  path.

## 3. Auth API

`lib/features/auth/data/auth_api.dart` talks to the existing backend endpoints
through the shared `ApiClient`:

- `POST /auth/login` (username **or** email) → `TokenResponse`,
- `POST /auth/register` → identity,
- `POST /auth/refresh` (raw, via `_http` in `AuthState`) → rotated token pair,
- `POST /auth/logout` (idempotent),
- `GET /auth/me` → current user.

Path constants remain centralized in `ApiPaths`.

## 4. Auth models

`lib/features/auth/domain/auth_models.dart`:

- `TokenResponse` — `accessToken`, `refreshToken`, `tokenType`, `expiresIn`;
  tolerant `fromJson`/`toJson`, value equality.
- `CurrentUser` — `userId`, `username`, `email`.
- `RegisterResult` — returned identity.
- `AuthStatus` enum backing the state machine in §1.

## 5. Auth validators

`lib/features/auth/domain/auth_validators.dart` — pure, unit-tested:

- `username` — trimmed, 3–32 chars, `[a-zA-Z0-9_.]` only.
- `email` — conservative structural check with `.` in the domain.
- `password` — 10–100 chars plus a letter and a digit (mirrors the backend).
- confirm-password — non-empty and matches; each returns its own message
  (`'Enter a username.'`, `'Password must be 10–100 characters long.'`,
  `'Passwords do not match.'`, …).

## 6. Auth page layout kit

`lib/features/auth/presentation/auth_layout.dart`:

- `AuthPageLayout` — centered, constrained (max-width 460) two-column page
  (brand mark + headline/benefits on the left for desktop, form column), a
  `SafeArea`, scrollable so compact viewports never clip.
- `AuthErrorBanner` — dismissible error banner surfaced from `auth.lastError`.
- `AuthFormField` — label + `AppTextField` + always-present helper text (kept
  for error spacing, so a validation message never shifts layout).

## 7. Login page

`login_page.dart`:
- Username/email field (`userMayBeEmail` hint) and password field with
  show/hide toggle + enter-to-submit.
- Client-side validation before any network call; friendly server banners for
  bad credentials / locked or disabled accounts / validation detail messages.
- In-flight state disables the form and shows a spinner in the CTA (with a
  stable screen-reader announcement).
- On success `AuthGuard` sends the signed-in user into the app; a `from`
  argument returns them to the protected page they originally tried to open.
- Footer links to the register page and a "back to landing" call to action.

## 8. Register page

`register_page.dart`:
- Username, email, password and confirm-password fields with validation
  messages, a live strength indicator ("Include a number", etc.), and
  show/hide toggles.
- Flags weak passwords and mismatched confirmation before submitting.
- Friendly banners for taken username / taken email / existing account.
- On success: "Account created. Sign in to continue." and return to sign-in.

## 9. AuthGuard & route policies

`auth_guard.dart` — the single place that owns navigation decisions:

- `AuthPolicy.publicOnly` (home, login, register, design-system): redirects
  authenticated callers to the landing page (or their preserved `from`).
- `AuthPolicy.protected` (profile, dashboard, tasks): silently shows a
  session-check loading view while `unknown`, and bounce unauthenticated
  callers to `/login` with their original route as `from`.
- Redirects only fire post-frame, once per state, and only while the guard's
  own route is current — so navigation never races or loops (see §21 for the
  self-redirect bug this design caught and now prevents).

## 10. App wiring

`app.dart`:
- `TodoApp` owns (or accepts, for tests) a single `AuthState`, calls
  `initialise()` on first frame, and exposes it through `AppScope`
  (`InheritedNotifier<AuthState>`, `app_scope.dart`).
- `AuthGuard`s are installed in `AppRouter.onGenerateRoute` so every route
  resolves its policy centrally without touching the feature screens.

## 11. Session-aware shell & landing

- `AuthenticatedScaffold` (auth/presentation) wraps every signed-in screen:
  `AppShell` with Dashboard/Tasks/Profile navigation plus the identity footer
  (avatar + username, profile and sign-out buttons with a confirmation dialog).
- `dashboard_page.dart` / `tasks_page.dart` now render inside that shell
  (still content placeholders — task functionality is out of scope).
- `home_page.dart` became session-aware: signed-out visitors see the sign-in
  CTA; signed-in visitors see "You are signed in as <username>", an
  "Open dashboard" button, and a "Restoring your session…" note while a
  cold-start refresh is in flight.

## 12. Profile API

`lib/features/profile/data/profile_api.dart`:

- `getProfile()` → `Profile` (404 `PROFILE_NOT_FOUND` surfaces as a typed
  exception so the page knows there is no profile yet).
- `updateProfile()` → full-replace PUT (all five fields; empty/blank values
  normalized to explicit `null`).
- `patchProfile(ProfilePatchRequest)` → PATCH with **only** the fields that
  changed; an explicit `null` clears a value, an omitted key leaves it
  untouched.
- All calls flow through `AppScope.apiOf(context)` — the authenticated
  `ApiClient` in `AuthState` — so a stale token triggers the transparent
  401 → refresh → retry cycle from §2.

## 13. Profile models & diffing

`lib/features/profile/domain/profile_models.dart` — `Profile`,
`ProfileUpdateRequest`, and `ProfilePatchRequest.buildChanges(existing…)` which
compares against the last-loaded profile and emits the minimal change set
(strings trimmed; blank → null). Value equality where it matters.

## 14. Profile validators

`profile_validators.dart` — display-name length and image-URL rules. The URL
check runs before any network call: it must be a valid `http(s)` URL
(`'Enter a valid http(s) URL (e.g. https://example.com/image.png).'`).

## 15. Timezone catalog

`timezone_catalog.dart` with platform adapters:
- `_io.dart` — reads the host's `TZ` database (`/usr/share/zoneinfo`) into
  candidate names,
- `_web.dart` — resolves candidates from the browser's `Intl` API
  (`dart:js_interop`),
- curated fallback list (UTC, Europe/London, Asia/Tokyo, …) so the selector is
  never empty, plus `looksLikeIanaTimezone` validation.

## 16. Profile page

`profile_page.dart` — two views:

- **Create** (404 `PROFILE_NOT_FOUND`): a friendly empty-state card with a
  "Create your profile" form (display name, timezone selector, profile image
  URL). First save uses PUT (upsert).
- **Edit**: pre-filled fields; subsequent saves use PATCH of only the changed
  fields; Reset restores the last-saved values; a "No changes to save" snackbar
  appears when nothing differs.
- Server errors on load show an error state with "Try again"; save failures
  keep the user on the form with a clear banner. Profile created/saved outcome
  is confirmed via snackbar.

## 17. Test strategy

- `test/support/mock_api.dart` — a fake backend over `package:http`'s
  `MockClient` with fixtures, request counters, and togglable behaviors
  (`failLogin`, `failLogout` (500), `failProfileGet` (500), `profileNotFound`,
  `ACCOUNT_LOCKED`, `USERNAME_ALREADY_TAKEN`, a one-shot rotating token pair,
  and an `refresh-expired` refresh token that forces a 401).
- `test/support/widget_test_harness.dart` — `pumpApp` pumps the real
  `TodoApp` with an injected `AuthState`.
- Pages are tested end-to-end widget tests (form → mock calls → redirects /
  banners / snackbars); data/state/HTTP layers get pure unit tests.

## 18. New tests (all in `test/`)

- `features/auth/auth_models_test.dart`, `auth_validators_test.dart`,
  `auth_api_test.dart`, `auth_state_test.dart` (lifecycle, login/register
  success+error, concurrent-refresh serialization, refresh-expired logout,
  best-effort logout), `auth_http_client_test.dart` (bearer injection,
  401 → refresh → retry, loop guard, refresh-failure), `login_page_test.dart`,
  `register_page_test.dart`.
- `features/profile/profile_api_test.dart` (GET parse, 404, PUT full body,
  PATCH minimal diff), `timezone_catalog_test.dart`, `profile_page_test.dart`
  (pre-fill, create→PUT→PATCH, URL validation blocks the network, load error +
  retry).
- `app_router_test.dart` extended: authenticated visitors are redirected off
  `/login`, the landing page never replaces itself, profile stays reachable.

## 19. Verification (exact outputs)

```
dart format lib test        → Formatted 80 files (1 changed) in 0.27 seconds.
flutter analyze             → No issues found! (ran in 4.8s)
flutter test --concurrency 8
                            → 00:07 +154: All tests passed!
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
                            → Compiling lib\main.dart for the Web... 57.1s
                            → √ Built build\web
```

## 20. Accessibility & responsiveness

- 48 px minimum touch targets; buttons announce a stable
  "…loading" label while `CircularProgressIndicator` runs; error banners are
  visible + announced text (no color-only signalling).
- Fields are labeled; text-scale clamping (≤1.6) from the app builder applies
  to the auth pages too.
- Login/register/profile use `ResponsiveContainer`/`AuthPageLayout` —
  single-column centered on compact widths, brand + form side-by-side on
  desktop; everything is scrollable, so tall forms never clip.
- No hardcoded viewport sizes; the timezone URL validator and validators run
  before any network or selector I/O.

## 21. Bugs found & fixed by the tests

1. **AuthGuard infinite self-redirect (the big one).** For a signed-in visitor
   the landing route (`/`, publicOnly) computed its *own* route as the redirect
   target and replaced itself with a fresh copy every navigation cycle —
   frames were scheduled forever (a `pumpAndSettle` never returned, and in the
   browser it would burn CPU indefinitely). Fixed in `auth_guard.dart`: a
   redirect whose target equals the guard's current route is a no-op. A
   regression test covers it.
2. **Profile create view had no Save button** — extracted a shared `_buildActions()`
   used by both the create and edit views.
3. **First profile save always re-PUT instead of PATCHing** — `_creating` was
   never reset after the initial upsert; the success path now resets it and the
   snackbar distinguishes 'Profile created.' vs 'Profile saved.'.
4. **`ProfilePage` hit `AppScope.apiOf` in `initState`** — moved API creation +
   bootstrap into `didChangeDependencies` behind a `_bootstrapped` guard.
5. **`AppButton` icon+label overflow in the narrow sidebar footer** — wrapped in
   `FittedBox(fit: BoxFit.scaleDown)`.
6. **Tests were wrongly `test()` instead of `testWidgets()`** in three files,
   and used 9-character passwords under a 10-character minimum — all fixed.
7. Existing `app_router` design-system test used `pumpAndSettle` on a page that
   deliberately contains a perpetual loading spinner → switched to the bounded
   pump convention already used by `design_system_page_test.dart`.

## 22. Security notes

- Access + refresh tokens live **only in memory** and are never persisted or
  logged; a browser reload forgets the session.
- No client-side credentials; `ApiClient` never sees backend secrets.
- The authenticated transport attaches the bearer header only on protected
  paths; refresh rotation is single-flight to respect one-time refresh tokens.
- Error translation never leaks internals, token values or stack traces.

## 23. Files created / modified

- **Created (lib)** — `features/auth/`: `domain/{auth_models,auth_validators}.dart`,
  `data/auth_api.dart`,
  `presentation/{auth_state,auth_http_client,app_scope,auth_guard,auth_layout,login_page,register_page,authenticated_scaffold}.dart`;
  `features/profile/`: `domain/{profile_models,profile_validators,timezone_catalog}.dart`
  (+`timezone_catalog_io.dart`, `timezone_catalog_web.dart`),
  `data/profile_api.dart`, `presentation/profile_page.dart`.
- **Created (test)** — `support/{mock_api,widget_test_harness}.dart`;
  `features/auth/{auth_models,auth_validators,auth_api,auth_state,auth_http_client,login_page,register_page}_test.dart`;
  `features/profile/{profile_api,timezone_catalog,profile_page}_test.dart`.
- **Modified** — `app.dart`, `presentation/router/app_router.dart`,
  `features/home/presentation/home_page.dart`,
  `features/dashboard/presentation/dashboard_page.dart`,
  `features/tasks/presentation/tasks_page.dart`,
  `shared/widgets/app_button.dart`, `test/app_router_test.dart`,
  `frontend/README.md`.

## 24. Warnings / issues / deviations

- The design-system showcase intentionally contains an always-animating loading
  button; tests must use bounded pumps there (documented in the test file).
- `flutter build web` prints a Wasm dry-run suggestion; not adopted — the
  standard (JS) web build is the phase's target, consistent with Phase 9.
- `timezone_catalog_io` reads the host `TZ` database; on systems without one it
  falls back to the curated list, so behavior is identical across platforms.
- No product/backend/schema/infra deviations; the dashboard/tasks screens
  remain intentional placeholders (task functionality is a later phase).

## 25. Confirmations

- **Backend / infrastructure NOT modified** — all changes are under
  `frontend/`; `backend/`, `infrastructure/`, and existing `docs/*` untouched.
- **Real APIs** — the UI talks to the existing `auth.*` and `profile` endpoints
  over the shared `ApiClient`; no fake login state, no hardcoded credentials.
- **Android/iOS NOT added** — `web/` remains the only platform directory.
- **No new runtime dependencies** (uses `http`, `cupertino_icons`,
  `dart:js_interop` — all available).
- **No commit created** — nothing staged; repository unchanged by git.
- Dashboard/tasks **task functionality is NOT implemented** (out of scope).

STOP.