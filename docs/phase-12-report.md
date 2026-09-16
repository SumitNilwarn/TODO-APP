# Phase 12 — Dashboard UI (Implementation Report)

**Status:** COMPLETE (verified)
**Date:** 2026-09-15
**Scope:** Flutter Web frontend (`frontend/`) only.

This report documents the state of the Phase 12 dashboard implementation as of
Phase 12 closure, the gaps found and fixed during Phase 12, the final
verification results, and every explicit confirmation requested by the Phase 12
prompt.

All commands were run with the Flutter toolchain located at
`C:\Users\Sumit\AppData\Local\Temp\opencode\flutter_sdk\flutter\bin`
(Flutter 3.47.4 / Dart 3.13.3). Working directory for verification:
`C:\Users\Sumit\VibeCode\TODO\frontend`.

---

## 1. What was built

A production-quality, responsive **dashboard screen** at `/dashboard` that
renders the user's task overview from **real, owner-scoped backend data**:

- **Six metric cards**: `Total`, `To Do`, `In Progress`, `Completed`,
  `Cancelled`, `Overdue` — in a responsive 1 / 2 / 3-column grid.
- **Status distribution**: four status bars (`To do`, `In progress`,
  `Completed`, `Cancelled`) with label, count, and a proportional fill built
  from Flutter primitives (no charting package).
- **Overdue section**: danger-tinting, per-task title + status + due date +
  "Overdue" badge, falling back to a positive **"You're all caught up"** empty
  state.
- **Recent tasks** (`createdAt DESC`, bounded to 10) and **Coming up**
  (`dueDateFrom=today`, `dueDate ASC`, bounded to 5).
- **Filter chips**: one status chip per persisted status
  (`To do`, `In progress`, `Completed`, `Cancelled`) plus an `Overdue only`
  toggle; both re-query the recent preview with the matching param.
- **"View all tasks"** affordance navigating to the `/tasks` route.
- **Refresh** (and **retry**): a refresh keeps current content visible with a
  thin progress line, **refuses overlapping refreshes** while in flight,
  and reports failures via `SnackBar`; full-screen loading appears only on the
  first load (no zero-value flashes).
- **States**: loading / error-with-retry / per-section empty states.
- **Architecture**: `features/dashboard/{data,domain,presentation}` following
  the Phase 11 lightweight pattern (plain `setState`, authenticated `ApiClient`
  via `AppScope`).

## 2. How it fulfills the Phase 12 requirements

| Requirement | Where |
| --- | --- |
| Metric cards (6 counters) | `DashboardPage._MetricTile`, `_metricTiles()` |
| Status distribution (native bars) | `DashboardPage._statusBars()` (`_StatusBar`) |
| Overdue section (title/status/due date/badge) | `DashboardPage._overdueSection()` (`_TaskRow`, `_OverdueBadge`) |
| Recent (createdAt DESC, ≤ 10) | `DashboardApi.getTasks(page: 0, size: 10, sort: createdAt DESC)` |
| Upcoming (dueDateFrom=today, ≤ 5) | `DashboardApi.getTasks(page: 0, size: 5, overdue: false, dueDateFrom: today, sort: dueDate ASC)` |
| Status filter chips | `DashboardPage._onStatusSelected` → refresh `with status` |
| Overdue-only filter | `DashboardPage._onOverdueOnlyChanged` → refresh `with overdue=true` |
| View all → `/tasks` | `Navigator.pushNamed(AppRouter.tasks)` |
| Refresh keeps content + dedupes | `_refresh()` guard `if (_refreshing || _loading) return;` |
| No zero-value flashes | `_loading=true` until first full load completes |
| Error state + retry (safe copy) | `AppErrorState` + `_friendlyLoadError` / `_friendlyRefreshError` |
| Empty states | per-section `AppEmptyState` (+ breakdown empty state) |
| Responsive 390–1440 | `LayoutBuilder`-driven metrics grid + `ResponsiveContainer` |
| Accessible | semantic metric/overdue labels, 48 px targets, 4.5:1 contrast, keyboard focus |
| No new dependencies | Flutter primitives only |
| No backend/infra changes | confirmed, §8 |
| No task CRUD | confirmed, §8 |
| Tests (api / models / page) | §1, §6 |
| README + report updated | §10 |

## 3. Data layer

`features/dashboard/data/dashboard_api.dart` — `DashboardApi` over the
authenticated `ApiClient`:

- `getSummary()` → `GET /api/v1/dashboard` → `DashboardSummary`.
- `getTasks({page, size, sort, direction, status, overdue, dueDateFrom})` →
  `GET /api/v1/tasks` → `DashboardTaskPage` (both endpoints return the
  `data` envelope from the existing `ApiClient`).

Requests for the four sections run in parallel via
`Future.wait<Object>([...], eagerError: true)`. **`eagerError: true` is
deliberate**: it was added because Dart record `.wait` throws
`ParallelWaitError`, which masked the real `ApiException` and made the error
UI fall back to generic copy instead of classifying the actual status. With
`eagerError`, the failure surfaces as the raw `ApiException` so the error
mapping can pick the correct message.

## 4. Domain models

`features/dashboard/domain/dashboard_models.dart` mirrors the exact wire
contracts (verified against the backend DTOs, Phase 12 prompt §9):

- `DashboardSummary` — `totalTasks, todoTasks, inProgressTasks,
  completedTasks, cancelledTasks, overdueTasks` with derived helpers.
- `DashboardTaskStatus` — `TODO, IN_PROGRESS, COMPLETED, CANCELLED`. `OVERDUE`
  is deliberately **not** a status; it is a derived flag on the task row.
- `DashboardTask` — `id, title, description, status, dueDate, completedAt,
  overdue, createdAt, updatedAt` (matching `TaskResponse` incl. `version`? —
  `version` is backend-owned and not surfaced on the read-only dashboard rows).
- `DashboardTaskPage` — `content, page, size, totalElements, totalPages,
  first, last` matching `TaskPageResponse`.

## 5. Presentation & state

`features/dashboard/presentation/dashboard_page.dart` — `DashboardPage`
(`StatefulWidget`, plain `setState`, no state-management package):

- Summary + recent + overdue + upcoming loaded in parallel on mount; all
  query params are **bounded** so the dashboard never downloads an unbounded
  list.
- **Error copy is status-aware and leak-free**: network/timeout → friendly
  message; 401 → session-expired; 403 → "You don't have permission…"; 404 →
  not-found; 5xx → "An unexpected server error occurred…"; 400/422 → backend
  `message`; otherwise generic. Backend detail strings are never rendered.
- Refresh keeps content visible, shows a thin progress indicator, disables the
  refresh action while in flight (preventing duplicate round-trips), and shows
  a `SnackBar` on failure.
- Semantics: metric tiles and the overdue badge expose a single merged label
  with `excludeSemantics` on their children so screen readers announce e.g.
  **"Total, 8"** once instead of the merged
  `"Total, 8\n8\nTotal"` (a real double-announcement bug found during audit).

## 6. Tests

Located in `frontend/test/features/dashboard/`:

| File | Count | Coverage |
| --- | --- | --- |
| `dashboard_models_test.dart` | 10 | wire parsing (full/zero/completed tasks), status resolution incl. `OVERDUE → null`, pagination, empty page |
| `dashboard_api_test.dart` | 7 | request paths, bounded pagination + default sort, optional filters, error surfacing |
| `dashboard_page_test.dart` | 15 | loading, render (metrics/status/overdue/rows incl. description), safe 500 error copy, 403 permission copy, retry, empty states, status chip re-query, overdue-only chip, duplicate-refresh prevention, in-place refresh, failed-refresh snackbar, View-all navigation, responsive no-overflow across 390/768/1024/1280/1440 |
| **Total** | **32** | |

The fake backend (`frontend/test/support/mock_api.dart`) renders the shared
`mockDashboard` / `mockTasks` fixtures and supports **configurable failures**
(per-endpoint status, code, message) and a **response delay** used to probe
refresh deduplication. `Behavior` additions made during Phase 12:
`dashboardErrorStatus/-Code/-Message`, `tasksErrorStatus/-Code/-Message`, and
`responseDelay`.

Failures found in the baseline and fixed during Phase 12:
1. Semantic double-announcement of metric labels (and `find.bySemanticsLabel`
   seeing `"Total, 8\n8\nTotal"`) → fixed with `excludeSemantics`.
2. Page-level errors swallowed by `ParallelWaitError` → fixed with
   `Future.wait(... , eagerError: true)`.
3. Raw backend error strings surfaced to users (`dashboard boom`) → replaced
   with status-aware safe copy.
4. Chip / "View all tasks" taps landing below the 800×600 test viewport →
   tests now `ensureVisible` before tapping.
5. A filtered re-query assertion assumed the status-carrying request was the
   *last* `/tasks` call; actually the *upcoming* query fires last → now asserts
   the filtered request exists.

## 7. Verification results (exact)

| Step | Command | Result |
| --- | --- | --- |
| Format | `dart format lib test` | `Formatted 85 files (1 changed)` — no errors |
| Analyze | `flutter analyze` | `No issues found!` |
| Tests (full) | `flutter test --concurrency 8` | `+186: All tests passed!` |
| Tests (dashboard) | `flutter test test/features/dashboard --concurrency 8` | `+32: All tests passed!` |
| Web build | `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` | `√ Built build\web` (compile ~115.8 s; output contains the standard Wasm dry-run note, which is informational — same non-fatal note Phases 10/11 reported) |

`flutter analyze` exit code 0; `flutter test` exit code 0; build produced
`build/web` successfully.

## 8. Scope confirmations

- **No changes** to `backend/` (controllers, services, DTOs, `TaskService`),
  PostgreSQL, Flyway migrations, Docker, or any infrastructure.
- **No Android / iOS / macOS / Windows / Linux app targets touched** — the new
  UI is web rendered (and verified responsive in the test harness at
  390–1440 px).
- **No CI/CD / GitHub Actions changes.**
- **No task CRUD** created — the dashboard only reads via the existing
  endpoints; `/tasks` remains a placeholder.
- **No fake/spun data**: every number comes from `GET /api/v1/dashboard` and
  every row from `GET /api/v1/tasks` (fixtures live only in test mocks).
- **No laggy/trolling/testing modes** introduced.
- **No extra packages** added (`pubspec.yaml` unchanged).
- **No git commit created** (repo remains untracked on `master`, as prior
  phases left it).
- Phase 11 patterns were reused: `AuthenticatedScaffold`, `ResponsiveContainer`,
  `AppLoading` / `AppErrorState` / `AppEmptyState`, `AppScope`, `AuthState`,
  `AuthenticatedHttpClient`, `AppDesignSystem`.

## 9. Files touched during Phase 12

Frontend code:
- `frontend/lib/features/dashboard/presentation/dashboard_page.dart`
  (`Future.wait eagerError`, error mapping, semantics, description line).

Tests:
- `frontend/test/support/mock_api.dart` (configurable failures + delay).
- `frontend/test/features/dashboard/dashboard_page_test.dart` (error-copy /
  permission / duplicate-refresh / ensureVisible / description tests).

Docs:
- `frontend/lib/features/dashboard/README.md` (rewritten from stale
  "placeholder" content).
- `frontend/README.md` (Phase 12 scope block, dashboard section, tree, route
  table, test list/count).
- `docs/phase-12-report.md` (this report).

## 10. Documentation

- `frontend/README.md` — full run-down: routes (incl. `/dashboard` now real),
  dashboard module docs pointer, testing section with the dashboard test list,
  and updated total (186 tests).
- `frontend/lib/features/dashboard/README.md` — module reference: data / domain
  / presentation layers, bounded-query rationale, responsive & a11y behavior,
  error-handling model, test strategy.
- `docs/phase-12-report.md` — this report.

## 11. Out of scope (Phase 12)

- Task CRUD (Phase 13+), advanced search/filter combos, add/edit dialogs.
- A real `/tasks` page (still the placeholder; the dashboard navigates to it).
- Backend endpoint changes or new aggregations.

## 12. Final state

✅ All Phase 12 features implemented and verified.
✅ `dart format` clean. ✅ `flutter analyze` clean.
✅ 186/186 tests pass (`--concurrency 8`), incl. 32 dashboard tests.
✅ `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` succeeds.
✅ Docs updated. ✅ No out-of-scope changes.