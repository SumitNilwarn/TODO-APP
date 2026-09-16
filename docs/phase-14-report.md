# Phase 14 — Search, Filters & Sorting for `/tasks` (Implementation Report)

**Status:** COMPLETE (verified)
**Date:** 2026-09-15
**Scope:** Flutter Web frontend (`frontend/`) only.

This report documents the Phase 14 search / filters / sorting implementation on
the `/tasks` list, the issues found and fixed during the phase, the final
verification results, and every explicit confirmation the Phase 14 scope
demands.

All commands were run with the Flutter toolchain located at
`C:\Users\Sumit\AppData\Local\Temp\opencode\flutter_sdk\flutter\bin`
(Flutter 3.47.4 / Dart 3.13.3). Working directory for verification:
`C:\Users\Sumit\VibeCode\TODO\frontend`.

---

## 1. What was built

Phase 14 extends the Phase 13 `/tasks` list so every search, filter and sort is
**server-backed** — an immutable `TaskListQuery` serialises to the existing
`GET /api/v1/tasks` query parameters, and the UI never re-filters an unbounded
list locally:

- **Search** — a filter `TextField` with a clear (✕) button. Keystrokes are
  debounced on a 300 ms timer, so rapid typing coalesces into a single request.
  Each fetch carries a monotonically increasing request id and stale responses
  are silently discarded. The trimmed value is sent as the `search` query
  parameter (case-insensitive substring over title + description, per the
  backend contract).
- **Filters** — status `ChoiceChip`s (`All`, `To do`, `In progress`,
  `Completed`, `Cancelled`), an `Overdue only` `FilterChip`, and a due-date
  range action chip that opens a bottom sheet with two `showDatePicker`s
  (`From` / `To`), a `Clear dates` action, and an `Apply` button. The range is
  sent as inclusive `dueDateFrom` / `dueDateTo` (`YYYY-MM-DD`).
- **Sort** — a `DropdownButton` over the backend allowlist (`createdAt` |
  `updatedAt` | `dueDate` | `title` | `status`) plus a direction toggle button
  (`ASC` / `DESC`). Default remains `createdAt DESC`.
- **Combined** — search, status, overdue, and the date range combine in a single
  request; any filter/sort change resets the page to 0. A `Clear filters`
  button (shown when any filter is active) resets search + filters while keeping
  the chosen sort/direction.
- **Empty states** — three distinct states: base (`You have no tasks yet`),
  search (`No tasks match your search` with `Clear search`), and filter
  (`No tasks match your current filters` with `Clear filters`).
- **Validation** — a range with `from > to` shows the inline
  `Start date must not be after end date.` and skips the fetch entirely.
- **Responsive** — the control rows are `Wrap`s that reflow instead of
  overflowing from 390 px up (no-overflow verified across 390/768/1024/1280/
  1440 px).

## 2. How it fulfills the Phase 14 requirements

| Requirement | Where |
| --- | --- |
| Search box (debounced, server-backed) | `_SearchBar` + `_onSearchChanged` (300 ms debounce) |
| Status + overdue + due-date-range filters | `_TaskControls` chips → `TaskListQuery` |
| Inclusive due-date bounds | bottom sheet `_DateRangeSheet` → `$TdueDateFrom/bounds` |
| Sorting (allowlisted field + direction) | `DropdownButton<TaskSortField>` + direction toggle |
| Combined filters in one request | `TaskListQuery.toQueryParams()` → `listTasksFromQuery` |
| Pagination reset on any change | `resetPage()` from every filter/sort handler |
| Stale-response discard / dedupe | `_requestId` guard + debounce coalescing |
| No local re-filtering of unbounded data | every change re-issues `GET /api/v1/tasks` |
| Empty states for search vs filters vs base | `_buildEmptyState` (three variants) |
| Backend unchanged | confirmed, §8 |
| No new dependencies | `pubspec.yaml` unchanged (confirmed) |
| Phase 12/13 tests not regressed | §7 (+34 tasks tests, `+287` total) |
| README + report updated | §10 |

## 3. Query model

`features/tasks/domain/task_list_query.dart` (new):

- **`TaskSortField`** — the exact backend allowlist (`createdAt | updatedAt |
  dueDate | title | status`) with `apiValue` (wire) and `label` (UI).
- **`TaskListQuery`** — immutable, owns the whole listing state: `page`, `size`,
  `sort`, `direction`, and the nullable `status`, `dueDateFrom`, `dueDateTo`,
  `overdue`, `search`.

Serialization contract:

- `toQueryParams()` sends **only non-default values** — blank search, `null`
  status, null date bounds and `overdue=false` are omitted, matching the
  backend's "absent = default" semantics (sending `overdue=false` would silently
  hide every task with no due date).
- Search is trimmed client-side, `status` uses `apiValue`, dates use the
  timezone-free `YYYY-MM-DD` format (`_isoDate`).
- `clearFilters()` keeps sort/direction and resets page; `resetPage()` derives a
  copy on page 0; `copyWith` uses a nullable-`Function()` pattern so optionals
  (`status`, `dueDateFrom`, `dueDateTo`) can be *cleared* as well as set.
- `==` / `hashCode` compare dates by calendar day only (a dotted time from a
  picker never breaks equality or the hash contract — a correctness bug fixed
  during Phase 14, see §6).

## 4. Data layer

`features/tasks/data/task_api.dart` gained **`listTasksFromQuery(TaskListQuery)`**
— a convenience wrapper that calls `_client.get<TaskPage>(ApiPaths.tasks,
queryParameters: query.toQueryParams())`. The Phase 13 `listTasks` overload is
preserved for back-compat and existing tests. The mock backend
(`test/support/mock_api.dart`) implements the same Phase 14 query contract so
widget/API tests exercise real server-backed behaviour:

- `search` — case-insensitive substring over title **or** description.
- `dueDateFrom` / `dueDateTo` — inclusive calendar-day bounds.
- `sort` + `direction` — comparator per allowlisted field, both directions
  (`_compareString` / `_compareIso` / `_compareDate`).

## 5. Presentation & state

`TasksPage` (`setState`, no state-management package) now hosts the query state
machine:

- `_query` is the **single source of truth**; every control writes a derived
  query (via `copyWith` + `resetPage`) and re-fetches. Calls that resolve to the
  same query short-circuit (no redundant request).
- **Search** — `_debounceTimer` (300 ms); the timer body trims and compares
  against `_query.search` before committing. `_clearSearch` clears the field
  and, when a search was active, commits `search: ''` + reload. The clear button
  appears only while text is present (via `ValueListenableBuilder`).
- **Dedupe / staleness** — `_requestId` increments per fetch; a response whose
  id no longer matches is discarded. The Phase 13 refresh overlap guard
  (`if (keepContent && _refreshing) return;`) is preserved.
- **`_TaskControls`** — responsive: desktop gets a horizontal split (status
  chips left, sort right), compact stacks the status chips then a `Wrap` of
  overdue / date-range / sort. The rows use `Wrap` so they reflow instead of
  overflowing; the `Clear filters` button appears when
  `query.hasActiveFilters`.
- **`_DateRangeSheet`** — bottom sheet with `From`/`To` `OutlinedButton`s that
  each open `showDatePicker` (`helpText: 'Due date from'/'to'`), `Clear dates`
  (visible once a date is set, pops with null/null), and `Cancel`/`Apply`.
  `_setDueDateRange` validates `from ≤ to`; an invalid range sets an inline
  error and **skips the fetch**.
- **`_SearchBar`** — plain `TextField` styled to the app theme with a search
  prefix icon and a clear suffix icon.

## 6. Tests

Located in `frontend/test/features/tasks/`:

| File | Count | Coverage |
| --- | --- | --- |
| `task_models_test.dart` | 15 | (Phase 13 — unchanged, passing) |
| `task_list_query_test.dart` | 14 | defaults; exact param serialization incl. omitting `overdue=false` / whitespace search; `copyWith` clearing; `resetPage`/`clearFilters`; active-filter accounting; equality + hashCode for calendar-day dates |
| `task_api_test.dart` | 24 | Phase 13 list/single/error + new `listTasksFromQuery` group: param forwarding (page/size/sort/direction), search + status + overdue + date bounds, omission of unset filters, case-insensitive search, inclusive bounds, ASC title sort |
| `tasks_page_test.dart` | 48 | Phase 13 (34, regression) + Phase 14: debounce timing + burst coalescing, clear button, search-empty state + restore, search+status combined + search-only clear, combined status+overdue (empty state), sort dropdown + page reset, direction toggle, filter-after-pagination resets page 0, clear-filters keeps sort, date-range pick → inclusive bounds, clear-dates refetch, `from > to` inline error + no fetch, responsive no-overflow, a11y semantics |
| **Total** | **101** | |

Issues found & fixed during Phase 14:

1. **`context.appColors` returns `AppThemeTokens`** — the new controls
   originally typed parameters as the static `AppColors`, which doesn't compile
   against the `ThemeExtension`. All control helpers use the `AppThemeTokens`
   type from `context.appColors` (the Phase 13 pattern).
2. **`clearFilters` couldn't clear nullable filters** — `copyWith` takes
   nullable-`Function()` params; passing bare `null` meant "no override", so
   `clearFilters` silently kept status/dates. Fixed to pass `() => null`.
3. **`hashCode` disagreed with `==`** — equality compares dates by calendar day
   but `Object.hash` hashed the raw `DateTime` (incl. time), breaking the hash
   contract. Dates are now hashed via a y/m/d key (`_dateKey`).
4. **Controls overflowed at default and 390 px widths** — two `Row`s (chips +
   date range on desktop, overdue + date + sort on compact) rendered
   `A RenderFlex overflowed by N pixels` at 800 px and 390 px. Replaced with
   self-wrapping `Wrap`s; verified no-overflow across the width sweep.
5. **Tapping controls below the 800×600 test viewport** — the added controls
   pushed rows and the `Next` button below the fold; Phase 13 tests that tapped
   tiles and `Next` directly now `ensureVisible` first (matches the form tests'
   existing pattern).
6. **Widget tests tapped `find.text('10')` in the calendar** — works because day
   cells are exact-text widgets; date assertions compute expected bounds from
   `DateTime.now()`'s current month so tests stay date-independent. A bounds
   range that matches nothing (fixtures are Jan-2026, pickers open on the
   current month) is asserted via the filter-empty state.

## 7. Verification results (exact)

| Step | Command | Result |
| --- | --- | --- |
| Format | `dart format lib test` | `Formatted 96 files (5 changed)` — no errors |
| Analyze | `flutter analyze --fatal-infos` | `No issues found!` |
| Tests (tasks) | `flutter test test/features/tasks` | `+101: All tests passed!` |
| Tests (full) | `flutter test` | `+287: All tests passed!` |
| Web build | `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` | `√ Built build\web` (standard informational Wasm dry-run note only) |

`flutter analyze` exit code 0; `flutter test` exit code 0; build produced
`build/web` successfully.

## 8. Scope confirmations

- **No changes to `backend/`** — `TaskController`, `TaskService`,
  `TaskSpecifications`, task DTOs, PostgreSQL, Flyway, Docker, and all
  infrastructure are untouched.
- **No Android / iOS / macOS / Windows / Linux app targets touched** — web only
  (responsive-verified at 390–1440 px in the test harness).
- **No CI/CD / GitHub Actions changes.**
- **No new dependencies** (`pubspec.yaml` unchanged).
- **No task CRUD added elsewhere** — the dashboard stays read-only; only the
  `/tasks` feature performs create/edit/status/delete.
- **Backend contract respected** — the client only sends parameters the
  documented `GET /api/v1/tasks` contract accepts (`page`, `size`, `sort` within
  the allowlist, `direction` ASC/DESC, `status` from the four persisted
  statuses, `overdue=true` only, `search` trimmed, inclusive `dueDateFrom`/
  `dueDateTo`). `OVERDUE` is never sent as a status; `overdue=false` is never
  sent; blank search is omitted.
- **No fake/spun data** — every read uses the real `/api/v1/tasks` endpoint;
  fixtures live only in test mocks.
- **Search/filter/sort are server-backed** — no local re-filtering of an
  unbounded list exists anywhere in the feature.
- **No laggy/trolling/testing modes introduced.**
- **No git commit created** (the repo remains untracked as prior phases left
  it).

## 9. Files touched during Phase 14

New feature files:
- `frontend/lib/features/tasks/domain/task_list_query.dart` — `TaskSortField` +
  `TaskListQuery`.

Modified feature files:
- `frontend/lib/features/tasks/data/task_api.dart` — `listTasksFromQuery`
  wrapper (Phase 13 `listTasks` preserved).
- `frontend/lib/features/tasks/presentation/tasks_page.dart` — query state
  machine, `_SearchBar`, `_TaskControls`, `_DateRangeSheet`, three empty states;
  also fixed the `clearFilters` + `hashCode` bugs above.

Tests:
- `frontend/test/features/tasks/task_list_query_test.dart` (new, 14).
- `frontend/test/features/tasks/task_api_test.dart` (+6 → 24).
- `frontend/test/features/tasks/tasks_page_test.dart` (+14 → 48; Phase 13 tests
  updated only for `ensureVisible` on below-fold taps).
- `frontend/test/support/mock_api.dart` — `search`, `dueDateFrom`/`dueDateTo`,
  `sort`/`direction` support with comparators.

Docs:
- `frontend/lib/features/tasks/README.md` (Phase 14 additions).
- `frontend/README.md` (Phase 14 scope block + "search, filters & sorting"
  section, test count 287).
- `docs/phase-14-report.md` (this report).

## 10. Documentation

- `frontend/README.md` — updated: Phase 14 scope block, folder tree, a dedicated
  "Tasks — search, filters & sorting (Phase 14)" section, and the testing
  inventory/count.
- `frontend/lib/features/tasks/README.md` — module reference extended: query
  model, wire-contract decisions, presentation/state machine, test strategy.
- `docs/phase-14-report.md` — this report.

## 11. Out of scope (Phase 14)

- Multi-column / richer list layouts, bulk actions, subtasks, sharing.
- Saved search / filter presets, natural-language queries.
- Any backend endpoint or DTO change (all searches/filters/sorts reuse the
  existing listing contract).
- Mobile-native targets.

## 12. Final state

✅ `/tasks` now supports server-backed search, filters and sorting.
✅ Single immutable `TaskListQuery` drives every fetch; params sent exactly as
   the backend contract specifies.
✅ Debounced search with stale-response discarding; combined filters; inclusive
   date-range bounds; allowlisted sort + direction; pagination reset on change.
✅ `dart format` clean. ✅ `flutter analyze` clean.
✅ 287/287 tests pass (incl. 101 tasks tests — 67 Phase 13 + 34 Phase 14 — and
   32 Phase 12 dashboard tests, not regressed).
✅ `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` succeeds.
✅ Docs updated. ✅ No out-of-scope changes.