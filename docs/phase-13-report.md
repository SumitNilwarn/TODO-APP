# Phase 13 — Task-Management UI (Implementation Report)

**Status:** COMPLETE (verified)
**Date:** 2026-09-15
**Scope:** Flutter Web frontend (`frontend/`) only.

This report documents the state of the Phase 13 task-management implementation,
the issues found and fixed during Phase 13, the final verification results, and
every explicit confirmation the Phase 13 scope demands.

All commands were run with the Flutter toolchain located at
`C:\Users\Sumit\AppData\Local\Temp\opencode\flutter_sdk\flutter\bin`
(Flutter 3.47.4 / Dart 3.13.3). Working directory for verification:
`C:\Users\Sumit\VibeCode\TODO\frontend`.

---

## 1. What was built

The `/tasks` **placeholder is replaced by a real, production-quality
task-management UI** backed entirely by the existing authenticated task
endpoints:

- **List** — one bounded page (size 15, `createdAt DESC`) with a total count,
  previous/next pagination, a page indicator, and a scrollable card list. Each
  tile shows title (ellipsized), due date, a one-line description when present,
  a status badge, and an "Overdue" badge — exposed to screen readers as a single
  merged label.
- **Filters** — an `All` chip, one chip per persisted status
  (`To do`, `In progress`, `Completed`, `Cancelled`), and an `Overdue only`
  toggle. Selecting any chip **replaces the whole selection** and re-queries
  page 0 with the matching query params; a filter-empty state offers
  "Clear filters".
- **Refresh** — keeps content on screen, shows a thin progress line, disables
  itself while in flight, and reports only failures via snackbar.
- **Detail** (deep link `/tasks/{id}`) — header card (badges, title,
  description), lifecycle actions (`Start` / `Complete` / `Cancel task`) — which
  disappear on terminal tasks — plus always-available `Edit` and `Delete`
  (delete confirmed via dialog), and a metadata card with due date, status,
  created / updated / completed timestamps.
- **Create / Edit form** — title (required), description (blank → `null`),
  and an optional timezone-free calendar due date via `showDatePicker` with a
  clear affordance. Create POSTs a full body; edit PATCHes **only the changed
  fields** (strings set, explicit `null` clears, untouched fields omitted) and
  stops with "No changes to save" when nothing changed.
- **Lifecycle** — Start / Complete / Cancel go through the dedicated endpoints
  so the backend enforces transition rules and owns `completedAt`. Recoverable
  failures (`INVALID_TRANSITION`, `OPTIMISTIC_LOCK_CONFLICT`) surface a snackbar
  with a **Refresh** action that reloads the row.
- **States** — loading, error-with-retry (safe, status-aware copy), per-state
  empty states, inline 400 field validation, and a non-technical submit banner.
- **Architecture** — `features/tasks/{data,domain,presentation}` following the
  Phase 11 lightweight pattern (plain `setState`, authenticated `ApiClient` via
  `AppScope`). No new packages, no backend changes.

## 2. How it fulfills the Phase 13 requirements

| Requirement | Where |
| --- | --- |
| `/tasks` placeholder replaced by real CRUD | `TasksPage` + detail + form (§1) |
| List via existing `GET /api/v1/tasks` (bounded page) | `TaskApi.listTasks(page, size: 15, createdAt DESC)` |
| Status + overdue-only filters as query params | `_FilterBar` → `listTasks(status:, overdue:)` |
| Pagination (prev/next, total, page indicator) | `_PaginationFooter` |
| Detail deep link `/tasks/{id}` | `AppRouter.taskDetailFor` → `TaskDetailPage` |
| Lifecycle Start/Complete/Cancel | `PATCH /status`, `/complete`, `/cancel` |
| Lifecycle rules / `completedAt` stay server-side | §3, §8 |
| Create form | `TaskFormPage` → `POST /tasks` (status defaults `TODO`) |
| Edit via PATCH (only changed fields, null clears) | `_buildPatch` → `TaskPatchRequest` |
| Delete with confirmation | `AppConfirmationDialog` → `DELETE /tasks/{id}` |
| Refresh keeps content + dedupes | `_load(keepContent: true)` + `_refreshing` guard |
| Error handling (safe copy, 401/403/404/5xx/400) | `TaskErrorCopy` |
| Optimistic-lock recovery (no destructive auto-retry) | 409 → snackbar with Refresh action |
| Accessible (semantics, focus, 48 px, no-overflow 390+) | §5 |
| No new dependencies | `pubspec.yaml` unchanged (confirmed) |
| No backend/infra/CI changes | confirmed, §8 |
| No task CRUD for **other** features | dashboard remains read-only (confirmed) |
| Tests (models / api / page) | §6 (`+67` tasks, `+253` total) |
| README + report updated | §10 |

## 3. Data layer

`features/tasks/data/task_api.dart` — `TaskApi` over the authenticated
`ApiClient`:

- `listTasks({page, size, sort, direction, status, overdue})` →
  `GET /api/v1/tasks`.
- `getTask(id)` → `GET /api/v1/tasks/{id}`.
- `createTask(CreateTaskRequest)` → `POST /api/v1/tasks`.
- `updateTask(id, UpdateTaskRequest)` → `PUT /api/v1/tasks/{id}` (full
  replacement).
- `patchTask(id, TaskPatchRequest)` → `PATCH /api/v1/tasks/{id}`.
- `updateTaskStatus(id, status)` → `PATCH /api/v1/tasks/{id}/status`.
- `completeTask(id)` / `cancelTask(id)` → `PATCH .../complete` / `.../cancel`.
- `deleteTask(id)` → `DELETE /api/v1/tasks/{id}`.

Wire-contract decisions:

- **`CreateTaskRequest.toJson`** always includes `description` (`null` when
  blank — the backend's `@NotBlankOrNull` rejects whitespace-only strings) and
  adds `dueDate` only when set. The client never sends `userId`, `completedAt`
  or `version`.
- **`UpdateTaskRequest.toJson`** always includes every editable field —
  `description` and `dueDate` appear as explicit `null` when absent, so a
  full-replacement PUT can genuinely clear them.
- **`TaskPatchRequest`** is an ordered map preserving the backend protocol:
  absent key = unchanged, explicit `null` = clear, string = set.
- **`listTasks` sends `overdue` only when the toggle is on.** A real bug found
  in Phase 13: sending `overdue=false` unconditionally silently filtered even
  the default All view to non-overdue tasks.

## 4. Domain models

`features/tasks/domain/task_models.dart` mirrors the exact backend contracts:

- `TaskStatus` (`TODO, IN_PROGRESS, COMPLETED, CANCELLED`) with `apiValue` /
  `label` and a lenient `fromApi` (unknown → `null`). `OVERDUE` is deliberately
  **not** a status.
- `Task` — full CRUD model including the server-owned `version` (optimistic
  lock) and the derived `overdue` flag; helpers `isTerminal`,
  `canStart/canComplete/canCancel`, `dueLabel`, `sameIdAs`.
- `TaskPage` — the `TaskPageResponse` envelope with `pageNumber` (1-based).
- `task_validators.dart` mirrors the backend limits (title 200, description
  2000) so the user gets instant feedback while the server stays authoritative.

## 5. Presentation & state

- **`TasksPage`** (`setState`, no state-management package). Filtering is one
  intent: a `TaskFilterSelection` record replaces the whole chip selection on
  every tap (`All` clears both `status` and `overdue` — fixed in Phase 13 after
  the original `_applyFilter` ignored explicit nulls and never reset). After a
  detail visit that mutated data, the current page reloads and steps back one
  page if it emptied.
- **`_TaskListTile`** — badges live in a `Wrap` below title/due-date/description
  rather than beside the title; this removes the horizontal overflow a fixed
  right-side badge caused at 390 px. The tile merges title + status + due date
  into one `Semantics` label.
- **`TaskDetailPage`** — per-action busy states (each button disables itself and
  shows its own spinner), mutated-flag so back pops `true`, snackbar feedback on
  every success, and a delete dialog that confirms before firing
  `DELETE /tasks/{id}`.
- **`TaskFormPage`** — shared create/edit. `_buildPatch` emits only changed
  fields with the explicit-`null` clear marker; due dates compare on y/m/d only
  so the picker's dotted time never looks like a change. Server 400 validation
  `details` map onto the matching fields; everything else shows the generic
  banner.

## 6. Tests

Located in `frontend/test/features/tasks/`:

| File | Count | Coverage |
| --- | --- | --- |
| `task_models_test.dart` | 15 | wire parsing (every field, absent optionals), calendar-date handling, unknown-status fallback, lifecycle/terminal helpers, pagination, date formatters |
| `task_api_test.dart` | 18 | request paths, bounded pagination/filter params, full-PUT vs minimal-PATCH serialization, explicit-null clears, dedicated lifecycle endpoints, `DELETE` → void, error surfacing (`TASK_NOT_FOUND`, `OPTIMISTIC_LOCK_CONFLICT`, `INVALID_TRANSITION`, 400 details) |
| `tasks_page_test.dart` | 34 | loading / error + retry / empty (base + filtered) / refresh-dedupe / filter re-query / All-reset / pagination; create (validation, blank→null, due date, server error); detail render + lifecycle + confirm/decline paths; delete (confirm, decline, failure); edit (minimal patch, null clears, no-changes, date clear); 404 + illegal-transition copy; responsive no-overflow 390/768/1280; a11y semantics |
| **Total** | **67** | |

The fake backend (`frontend/test/support/mock_api.dart`) grew a mutable task
store with request counters and configurable failures so the widget suite can
exercise real write round-trips and refresh-after-mutation.

Issues found & fixed during Phase 13:

1. List tiles **overflowed at 390 px** (status badge beside a long title left no
   room) → badges moved into a `Wrap` below the text; verified no-overflow by
   probing the debug exception channel in the 390/768/1280 test.
2. `overdue: false` was sent on every list query, hiding non-filtered tasks →
   only send `overdue` when the toggle is on.
3. `Navigator.pushNamed<bool>` threw
   `type 'MaterialPageRoute<dynamic>' is not a subtype of 'Route<bool?>?'` → the
   detail route is now built by a generic `_page<T>` with `_page<bool>`.
4. Filter reset ignored explicit `null` (`if (status != null)` guard) → the
   `All` chip could never clear a status → selection is now a full record that
   always overwrites state.
5. Chips filtered by `find.text('Completed')` collided with the status badge in
   tiles → tests use `find.widgetWithText(ChoiceChip, …)`.
6. Form submit buttons sat below the 800×600 test viewport → tests
   `ensureVisible` before tapping.
7. Delete dialog copy is one combined string → tests use `find.textContaining`.
8. `find.bySemanticsLabel('Refresh tasks')` never matched the icon button →
   tests assert the tooltip (`find.byTooltip`), the actual a11y surface.

## 7. Verification results (exact)

| Step | Command | Result |
| --- | --- | --- |
| Format | `dart format lib test` | `Formatted 94 files (12 changed)` — no errors |
| Analyze | `flutter analyze lib test --fatal-infos` | `No issues found!` (6.7s) |
| Tests (tasks) | `flutter test test/features/tasks --concurrency 4` | `+67: All tests passed!` |
| Tests (dashboard) | `flutter test test/features/dashboard --concurrency 4` | `+32: All tests passed!` (Phase 12 not regressed) |
| Tests (full) | `flutter test --concurrency 8` | `+253: All tests passed!` |
| Web build | `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` | `√ Built build\web` (output includes the standard informational Wasm dry-run note, same non-fatal note Phases 10–12 reported) |

`flutter analyze` exit code 0; `flutter test` exit code 0; build produced
`build/web` successfully.

## 8. Scope confirmations

- **No changes to `backend/`** — controllers, services, DTOs, `TaskService`,
  PostgreSQL, Flyway migrations, Docker, and all infrastructure are untouched.
- **No Android / iOS / macOS / Windows / Linux app targets touched** — web only
  (and responsive-verified in the test harness at 390–1440 px).
- **No CI/CD / GitHub Actions changes.**
- **No task CRUD added elsewhere** — the dashboard stays read-only; only the
  `/tasks` feature performs create/edit/status/delete.
- **Backend contract respected** — ownership and `completedAt` are never sent by
  the client; lifecycle transitions and versioning stay server-authoritative;
  the derived `overdue` flag is never stored or sent as a status.
- **No fake/spun data** — every read and write uses the real `/api/v1/tasks`
  endpoints; fixtures live only in test mocks.
- **No extra packages added** (`pubspec.yaml` unchanged).
- **No laggy/trolling/testing modes introduced.**
- **No git commit created** (the repo remains untracked on `master`, as prior
  phases left it).
- Phase 11/12 patterns reused: `AuthenticatedScaffold`, `ResponsiveContainer`,
  `AppLoading` / `AppErrorState` / `AppEmptyState` / `AppSnackbar` /
  `AppConfirmationDialog`, `AppScope`, `AuthState`, `AuthenticatedHttpClient`,
  `AppDesignSystem`.

## 9. Files touched during Phase 13

New feature files:
- `frontend/lib/features/tasks/data/task_api.dart`
- `frontend/lib/features/tasks/domain/task_models.dart`
- `frontend/lib/features/tasks/domain/task_validators.dart`
- `frontend/lib/features/tasks/presentation/tasks_page.dart`
- `frontend/lib/features/tasks/presentation/task_detail_page.dart`
- `frontend/lib/features/tasks/presentation/task_form_page.dart`
- `frontend/lib/features/tasks/presentation/task_error_copy.dart`

Wiring:
- `frontend/lib/presentation/router/app_router.dart` (task detail routes, generic
  `_page<T>` + `_page<bool>` — fixes the pushNamed cast error).

Tests:
- `frontend/test/features/tasks/task_models_test.dart`
- `frontend/test/features/tasks/task_api_test.dart`
- `frontend/test/features/tasks/tasks_page_test.dart`
- `frontend/test/support/mock_api.dart` (mutable task store, counters,
  configurability for task writes)
- `frontend/test/features/dashboard/dashboard_page_test.dart` (Phase 12 test
  updated to expect the real Tasks page — passing)

Docs:
- `frontend/lib/features/tasks/README.md` (new — full module reference).
- `frontend/README.md` (Phase 13 scope block, tasks module + route table, Tasks
  section, test list/count 253).
- `docs/phase-13-report.md` (this report).

## 10. Documentation

- `frontend/README.md` — updated: Phase 13 scope block, folder tree, `/tasks`
  + `/tasks/{id}` routes, full "Tasks (Phase 13)" section, testing inventory and
  count (253).
- `frontend/lib/features/tasks/README.md` — module reference: data / domain /
  presentation layers, wire-contract decisions, error model, test strategy.
- `docs/phase-13-report.md` — this report.

## 11. Out of scope (Phase 13)

- Multi-column / richer list layouts, bulk actions, subtasks, sharing.
- Advanced search and combined-filter expressions.
- Any backend endpoint or DTO change.
- Mobile-native targets.

## 12. Final state

✅ `/tasks` placeholder replaced by full, working task CRUD.
✅ All writes use the existing endpoints with the correct wire contracts.
✅ `dart format` clean. ✅ `flutter analyze` clean.
✅ 253/253 tests pass (`--concurrency 8`), incl. 67 tasks tests and 32
    dashboard tests (Phase 12 not regressed).
✅ `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` succeeds.
✅ Docs updated. ✅ No out-of-scope changes.