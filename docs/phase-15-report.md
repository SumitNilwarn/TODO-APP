# Phase 15 — Frontend ↔ Backend Integration Hardening (Verification Report)

**Status:** COMPLETE (verified)
**Date:** 2026-09-15
**Scope:** Flutter Web frontend (`frontend/`) fixes + contract tests; backend/`verified only — no backend code changed.

This report documents the Phase 15 integration audit: every frontend↔backend
surface was inspected against the documented contract, four genuine integration
defects were found and fixed, regression tests were added so the fixes cannot
silently regress, and both stacks were re-verified end to end.

All frontend commands ran with the Flutter toolchain at
`C:\Users\Sumit\AppData\Local\Temp\opencode\flutter_sdk\flutter\bin`
(Flutter 3.47.4 / Dart 3.13.3) from `C:\Users\Sumit\VibeCode\TODO\frontend`.
Backend verification used Maven 4.0.0-rc-6 with JDK 21.0.12.1 (Microsoft)
against Testcontainers PostgreSQL 16 on Docker.

---

## 1. What Phase 15 covers

A full integration audit of the Phase 9–14 frontend against the live Phase 3–7
backend REST API. The audit surfaced four genuine defects where the client
either diverged from the real wire contract or shipped a latent bug that the
existing test mocks had been masking; all four were fixed in `frontend/` only.

## 2. Audit surfaces inspected

- Request/response envelopes (`ApiResponse` / `ApiError`) vs. the real backend
  shape (`success`, `error.code|message|details`, top-level `timestamp`/`path`).
- The `ApiClient` transport (headers, timeout, error decoding, interceptors).
- The authenticated transport `AuthenticatedHttpClient` (public-path set,
  401→refresh→retry).
- Security chain public routes (`permitAll`), CORS, exposed headers.
- Task list contract (query params, max search length, sort allowlist,
  pagination), task lifecycle/optimistic-locking.
- Health, profile, dashboard, auth endpoints, and the in-memory auth state.
- Test support (`mock_api.dart`) fidelity to the real wire format.

## 3. Frontend↔backend contract facts confirmed

- Error envelopes carry `timestamp`/`path` at the **top level only** — never
  inside the `error` block (confirmed against
  `GlobalExceptionHandler`/`ErrorResponse` and `CorrelationIdFilter` logs).
- The backend `CorrelationIdFilter` reads `X-Correlation-Id`, puts it in the
  MDC, logs it on every line, and **echoes it on the response header**; CORS
  explicitly exposes `X-Correlation-Id` to browsers.
- Public in the security chain: `POST /api/v1/auth/register|login|refresh|
  logout`, `/api/v1/health/**`, Swagger/OpenAPI and `OPTIONS` preflight.
- `GET /api/v1/tasks` `search` accepts at most **200 chars**
  (`TaskService.MAX_SEARCH_LENGTH = 200`).
- Sort allowlist: `createdAt | updatedAt | dueDate | title | status`; direction
  `ASC|DESC`; `overdue=false` is a valid filter ("everything not overdue").

## 4. Defect found — no request correlation id

**Symptoms:** the browsers register every request/response independently; when a
request failed there was no way to find the corresponding backend log line, and
the backend's echoed `X-Correlation-Id` response header was never read.

**Gap:** `ApiClient` sent neither `X-Correlation-Id` nor captured the echo.

**Fix (frontend only):**
- `lib/data/api/api_client.dart` — every request now sends a fresh
  `X-Correlation-Id` (`correlationIdHeader` const; static
  `_generateCorrelationId()` produces a 32-char lowercase hex string from
  `Random.secure()` over 16 bytes, well under the backend's 64-char ceiling).
  A caller-supplied header **wins** (`putIfAbsent`, not overwrite). The
  response echo is captured into `ApiResponseData.correlationId`.
- `lib/data/api/api_interceptor.dart` — `ApiResponseData` gained the
  `correlationId` field.
- `lib/data/api/api_exception.dart` — `ApiException` gained `correlationId`;
  all server exceptions now carry the trace id.
- Also fixed in the same file: a latent variable-shadowing bug
  (`headers` param overwriting local state) → renamed to `requestHeaders`.

**Tests added:** `test/api_client_test.dart` group **"ApiClient — correlation
ids"** (fresh per-request id on sequential requests; caller-supplied id
respected; backend echo captured on a server error).

## 5. Defect found — errors dropped the outer envelope path/timestamp

**Symptoms:** on a non-2xx the client used `error.path`/`error.timestamp`, but
the backend never puts those inside the `error` block — they are top-level
envelope fields. The exception therefore surfaced `null` path/timestamp.

**Root cause:** `ApiClient._decode` parsed only `envelope.error` and discarding
`envelope.path`/`envelope.timestamp`.

**Fix (frontend only):**
- `lib/data/api/api_client.dart` — `_decode` now forwards
  `envelope.path`/`envelope.timestamp`/`response.correlationId` into
  `ApiException.fromError`.
- `lib/data/api/api_exception.dart` — `ApiException.fromError` accepts
  `path`, `timestamp`, `correlationId` overrides that take precedence over the
  (typically absent) nested values.

**Tests added:** `test/api_client_test.dart` — "forwards the outer-envelope path
and timestamp into the exception".

## 6. Defect found — health routes re-attached the bearer token

**Symptoms:** `AuthenticatedHttpClient_publicPaths` only covered the four auth
paths. `/api/v1/health` and `/api/v1/health/readiness` are `permitAll` server
side, but the client attached `Authorization: Bearer …` to them and would
attempt a (pointless) 401→refresh→retry if one failed.

**Fix (frontend only):**
- `lib/features/auth/presentation/auth_http_client.dart` — added
  `_healthPrefix = '${ApiPaths.v1}/health'` and `path.startsWith(_healthPrefix)`
  in `_isPublic`, replacing the previous (stale) exact `'/health'` check. The
  auth paths remain a single-path set; health is treated as a prefix family.

**Tests added:** `test/features/auth/auth_http_client_test.dart` — "health
endpoints stay public: no bearer header and no 401-refresh retry" (covers
`/api/v1/health` and `/api/v1/health/readiness`, asserting neither sends a
token nor triggers `attemptRefresh`).

## 7. Defect found — task search field had no server-limit cap

**Symptoms:** `TaskService.MAX_SEARCH_LENGTH = 200`; a query longer than 200
chars returns `400 VALIDATION_ERROR`. The UI allowed arbitrary-length input, so
a long paste produced a confusing server error instead of capping input.

**Fix (frontend only):**
- `lib/features/tasks/presentation/tasks_page.dart` — the search `TextField`
  now has `maxLength: kTaskSearchMaxLength` with `counterText: ''` (no
  distracting character counter), and `_onSearchChanged` drops any input that
  still exceeds the bound (`trimmed.length > kTaskSearchMaxLength` returns
  early) — so even programmatic/IME input cannot exceed the contract.
- `lib/features/tasks/domain/task_validators.dart` — added
  `const int kTaskSearchMaxLength = 200`, documented as mirroring
  `TaskService.MAX_SEARCH_LENGTH`.

**Tests added:** `test/features/tasks/tasks_page_test.dart` — "the search field
caps input at the backend limit of 200".

## 8. Test-support fix — mock error envelope shape

**Gap:** `test/support/mock_api.dart` `errorEnvelope` emitted
`timestamp`/`path` **inside** the nested `error` block — the exact opposite of
the real backend (top level only). This is precisely why §4/§5 defects passed
the old suite: the mock masked them.

**Fix (test-only):** `errorEnvelope` now emits `success`, `error` (with
`code`/`message`/`details`), and top-level `timestamp`/`path`, matching the
documented `docs/api-overview.md` shape.

## 9. Backend changes

**None.** `backend/` was not modified in Phase 15. The audit work was entirely
frontend fixes + tests plus backend *verification*.

## 10. Files changed (frontend source)

- `lib/data/api/api_client.dart`
- `lib/data/api/api_exception.dart`
- `lib/data/api/api_interceptor.dart`
- `lib/features/auth/presentation/auth_http_client.dart`
- `lib/features/tasks/domain/task_validators.dart`
- `lib/features/tasks/presentation/tasks_page.dart`

## 11. Files changed (tests / test support)

- `test/api_client_test.dart` (+4: envelope path/timestamp forwarding + 3
  correlation-id tests)
- `test/features/auth/auth_http_client_test.dart` (+1: health stays public)
- `test/features/tasks/tasks_page_test.dart` (+1: search cap at 200)
- `test/support/mock_api.dart` (error envelope wire shape)

## 12. Documents updated

- `docs/phase-15-report.md` (this report)
- `frontend/README.md` (Phase 15 scope block + integration notes + test count
  293)
- `frontend/lib/data/README.md` (correlation-id behaviour of `ApiClient`)

## 13. Backend unit + integration verification

Command (backend/):

```
$env:JAVA_HOME = "C:\Users\Sumit\.jdks\ms-21.0.12.1"
& "C:\Users\Sumit\AppData\Local\Temp\opencode\maven\apache-maven-4.0.0-rc-6\bin\mvn.cmd" -q verify
```

Result: **`EXIT=0`, BUILD SUCCESS** — full output captured to
`C:\Users\Sumit\AppData\Local\Temp\opencode\mvn-verify-backend.log`.

## 14. Backend test tallies

All 13 unit test classes passed (`surefire-reports/*.txt`: Failures 0, Errors
0). All 10 integration-test classes passed (`failsafe-reports/*.txt`,
**135 IT tests, Failures 0, Errors 0, Skipped 0**):

| Class | Tests |
| --- | --- |
| `AuthIntegrationIT` | 17 |
| `TaskApiIT` | 46 |
| `ProfileApiIT` | 16 |
| `TaskRepositoryIT` | 12 |
| `UserRepositoryIT` | 12 |
| `TodoApplicationIT` | 8 |
| `DashboardApiIT` | 6 |
| `DatabaseSchemaIT` | 6 |
| `UserProfileRepositoryIT` | 5 |
| `RefreshTokenRepositoryIT` | 7 |
| **Total** | **135** |

The suite ran against real PostgreSQL 16 (Testcontainers), exercised the full
security chain (register/login/refresh rotation, 401s, health `permitAll`,
correlation-id filter logging on every request), Flyway migrations V1–V4, and
the task lifecycle/pagination/search contracts.

## 15. Frontend static analysis

Command (frontend/):

```
flutter analyze
```

Result: **`No issues found!`** (exit 0).

## 16. Frontend formatting

Command:

```
dart format lib test
```

Result: clean, no reported changes.

## 17. Frontend tests

Command:

```
flutter test
```

Result: **`+293: All tests passed!`** (exit 0; 287 before Phase 15, +6 new
tests).

## 18. Frontend production web build

Command:

```
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

Result: **`√ Built build\web`** in ~60 s (only the standard informational Wasm
dry-run line appears on stderr; not a failure). Build exited 0.

## 19. Cross-stack verification matrix

| Concern | Backend | Frontend |
| --- | --- | --- |
| Correlation id generated + echoed | `CorrelationIdFilter` (seen in IT logs on every request) | new tests (fresh id/echo respect) |
| Error envelope top-level path/timestamp | verified in IT output | new test + exception fields |
| Health routes public | `permitAll` (IT logs show 200 without auth) | new test (no bearer, no refresh) |
| Search ≤ 200 | `TaskService.MAX_SEARCH_LENGTH` | new test (input capped at 200) |
| Overdue/sort/pagination params | IT `TaskApiIT` + `TaskRepositoryIT` | `task_list_query_test` / `task_api_test` |
| Auth refresh rotation | `AuthIntegrationIT` (17) | `auth_state_test` / `auth_http_client_test` |

## 20. Regression assurance

- All 12 prior-phase feature test files run unchanged and pass, with +6
  tests added this phase.
- The mock backend now emits the real error-envelope shape, so any future
  regression of §4/§5 would fail fast instead of being masked by
  test-support.
- No prior test was weakened or deleted; the two Phase 14 `tasks_page_test`
  search tests asserting the 200-cap still pass.

## 21. Scope confirmation — backend untouched

No `backend/` source, test, migration, Docker, or config file was modified in
Phase 15.

## 22. Scope confirmation — no new dependencies

`pubspec.yaml` / `pubspec.lock` unchanged; no new packages (the correlation-id
generator uses `dart:math` `Random.secure()`; no crypto dependency).

## 23. Scope confirmation — no secrets or credentials

No secrets, tokens, passwords, API keys or personal data added to any file;
nothing logged beyond the existing server-side MDC correlation id.

## 24. Scope confirmation — no UI redesign

No layout, theme, or UX change beyond the search-field `maxLength`/counter
suppression (a contract-alignment control, not a redesign).

## 25. Scope confirmation — no CI/CD changes

No GitHub Actions, pipeline, or build-config changes were made.

## 26. Scope confirmation — no native targets touched

Android/iOS/macOS/Windows/Linux targets untouched; everything stays
web-first as in prior phases.

## 27. Scope confirmation — no feature endpoints added

No new backend endpoint and no new frontend API surface; all fixes augment the
existing `ApiClient`/`AuthenticatedHttpClient` behaviour and one form control.

## 28. Scope confirmation — no fake or spun data

The app still reads only real `/api/v1/*` endpoints through the authenticated
client; fixture data exists solely in `test/support/mock_api.dart`.

## 29. Scope confirmation — auth model unchanged

In-memory session, JWT bearer + refresh rotation, `204`-free envelope
handling and logout semantics are untouched; only the public-path predicate for
health was corrected.

## 30. Scope confirmation — no git commit

Nothing was committed in Phase 15 (repo remains untracked, as prior phases left
it).

## 31. Known limitations (unverified-by-design)

- A single real-browser (Chrome → localhost:8080) manual smoke test was not
  performed this phase; contract fidelity is proven by the 293 frontend tests +
  135 backend IT tests + the clean production build. The next phase should run
  `flutter run -d chrome` against a live backend for the visual E2E pass.
- No backend change or re-deploy was required or performed (none was needed).

## 32. Final state

✅ Four genuine integration defects found during the audit and fixed
   (correlation-id support, error-envelope path/timestamp, health public
   route, search length cap).
✅ Test support mis-shape that masked two of them corrected.
✅ `flutter analyze` clean, 293/293 frontend tests pass, web build succeeds.
✅ Backend `mvn verify` exits 0 — 13 unit classes + 10 IT classes (135 IT
   tests) green against real PostgreSQL.
✅ No backend change, no new dependencies, no secrets, no git commit —
   every Phase 15 scope confirmation above is verified, not assumed.