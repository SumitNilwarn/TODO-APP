# features/tasks

Task-management feature module (Phase 13 + Phase 14) — real CRUD for `/tasks`,
replacing the placeholder. Reads and writes go exclusively to the existing
`/api/v1/tasks` endpoints through the authenticated `ApiClient`; ownership is
resolved server-side, so the client never sends a `userId`, `version`,
`completedAt` or any status the backend does not persist. Phase 14 keeps the
list fully server-backed: search, status/due-date filters and sorting are query
parameters on the same endpoint — there is no local re-filtering of an
unbounded list.

## Overview

What `/tasks` provides:

- **List** (`GET /api/v1/tasks`) — one bounded page (size 15, `createdAt DESC`)
  with search (debounced), status chips, a due-date range, an overdue-only
  toggle, a sort-field dropdown + direction toggle, previous/next pagination, a
  total count, and refresh / loading / error / empty states (plain, search, and
  filter variants).
- **Detail** (`GET /api/v1/tasks/{id}`, deep link `/tasks/{id}`) — full task
  state (title, description, status, due date, created/updated/completed
  timestamps) plus the lifecycle actions.
- **Create** (`POST /api/v1/tasks`) — title (required), description (blank maps
  to `null`), optional calendar due date. Status defaults to `TODO` server-side.
- **Edit** (`PATCH /api/v1/tasks/{id}`) — a partial patch that sends **only the
  changed fields**: strings set, explicit `null` clears `description`/`dueDate`,
  untouched fields are omitted entirely (the backend's three-state protocol).
- **Lifecycle** — `PATCH .../status` (Start), `.../complete` (Complete),
  `.../cancel` (Cancel, behind a confirmation dialog) through the dedicated
  endpoints so the backend enforces transition rules and owns `completedAt`.
- **Delete** (`DELETE /api/v1/tasks/{id}`) — destructive action behind a
  confirmation dialog; requires no status precondition (the backend permits it
  from any state).

## Architecture

```
features/tasks/
├── data/          → task_api.dart (TaskApi over ApiClient + request bodies)
├── domain/        → task_models.dart (Task, TaskStatus, TaskPage, date utils),
│                    task_validators.dart (mirrors backend field rules),
│                    task_list_query.dart (TaskSortField, TaskListQuery —
│                    the single source of truth for a listing fetch)
└── presentation/  → tasks_page.dart (list + search bar + filter/sort controls
                     + pagination), task_detail_page.dart, task_form_page.dart,
                     task_error_copy.dart (safe, status-aware copy)
```

All requests flow through `AppScope.apiOf(context)` — the authenticated
`ApiClient` built by `AuthState`, so every request carries the bearer token and
benefits from the transparent 401 → refresh → retry cycle. No second
authentication mechanism and no token handling lives in task code.

## Domain models

- `TaskStatus` — the four persisted statuses (`TODO`, `IN_PROGRESS`,
  `COMPLETED`, `CANCELLED`) with `apiValue`/`label`. **`OVERDUE` is absent**: it
  is a derived flag the server computes per task, never a status the client can
  send.
- `Task` — the full CRUD model (unlike the read-only dashboard projection). It
  carries `version`, the optimistic-lock counter the backend increments on every
  write; a stale concurrent write surfaces as 409 `OPTIMISTIC_LOCK_CONFLICT`.
  Helpers: `isTerminal`, `canStart/canComplete/canCancel`, `dueLabel`,
  `sameIdAs` (identity for list diffing after a mutation).
- `TaskPage` — the `TaskPageResponse` envelope (`content`, `page`, `size`,
  `totalElements`, `totalPages`, `first`, `last`, 1-based `pageNumber`).
- `TaskPatchRequest` — an ordered map of wire field name → new value; a `null`
  value is the clear marker, absent keys mean "unchanged".
- `TaskSortField` — the five backend-allowlisted sort fields (`createdAt` |
  `updatedAt` | `dueDate` | `title` | `status`) with `apiValue` + `label`.
- `TaskListQuery` — the immutable query state for one `GET /api/v1/tasks`
  fetch: `page`, `size`, `sort`, `direction`, `status`, `dueDateFrom`,
  `dueDateTo`, `overdue`, `search`. `copyWith` (nullable-`Function()` pattern so
  optionals can be cleared), `resetPage`, `clearFilters` (keeps sort/direction),
  `toQueryParams` (only non-default values sent), `hasActiveFilters` /
  `activeFilterCount`, and value equality with calendar-day date comparison.

## Wire-contract decisions (important)

- `UpdateTaskRequest` (PUT) always includes **every editable field**, sending
  `null` for absent `description`/`dueDate` — full-replacement semantics so the
  explicit-null fields are never dropped.
- `CreateTaskRequest` (POST) always includes `description` (`null` when blank —
  the backend's `@NotBlankOrNull` rejects whitespace-only strings, so the client
  never sends blank text) and adds `dueDate` only when set.
- `listTasks` sends `overdue` **only when the toggle is on**. Sending it
  unconditionally (even `false`) would silently filter the *default All view* to
  non-overdue tasks — a real bug caught during Phase 13.
- `TaskListQuery.toQueryParams` mirrors the backend's "absent = default"
  semantics: blank search, `overdue=false`, null status and null date bounds are
  omitted. Search is trimmed client-side and capped at 200 chars (client
  `maxLength` + programmatic guard) to match the backend's
  `MAX_SEARCH_LENGTH = 200`.
  Date bounds are sent as `YYYY-MM-DD` (`isoDateString`), matching the wire
  format and the backend's inclusive `dueDateFrom`/`dueDateTo`.
- Dates are timezone-free calendar days: `Task.dueDate` is parsed to
  `YYYY-MM-DD` with no time component (`_parseDate` drops it), `isoDateString`
  re-serializes exactly, and the edit form compares due dates on y/m/d only so a
  dotted time from the picker never counts as a change.

## Presentation

- **List** (`TasksPage`) — `setState`-owned state (the Phase 11 lightweight
  pattern). A single immutable `TaskListQuery` is the source of truth; every
  control writes a derived query and re-fetches page 0 (filters/sort/search all
  reset pagination). Search debounces on a 300 ms timer and every fetch carries
  a monotonically increasing request id so stale responses are silently
  discarded. The refresh keeps content on screen, disables itself while in
  flight (overlap guard), and reports only failures via snackbar. After a detail
  visit that mutated the data, the current page reloads (stepping back one page
  if it empties).
- **Search** — a filter `TextField` with a clear button and a debounced
  server-backed query (no client-side filtering). A no-match search renders a
  dedicated `No tasks match your search` empty state with a `Clear search`
  action.
- **Controls** — status chips (`All`, `To do`, `In progress`, `Completed`,
  `Cancelled`), an `Overdue only` chip, a due-date range action chip that opens a
  bottom sheet backed by `showDatePicker` (with `Clear dates`), a sort-field
  `DropdownButton`, a direction toggle button, and a `Clear filters` button. The
  rows are `Wrap`s so they reflow instead of overflowing on narrow widths.
  A range with `from > to` shows an inline error and skips the fetch.
- **Tile** — title (ellipsized), due date, one-line description, then a `Wrap`
  of the status badge + Overdue badge. The tile exposes a single merged
  semantics label (title, status, due date) and is fully keyboard-operable. The
  badge `Wrap` prevents the horizontal overflow a fixed right-side badge caused
  at 390 px.
- **Detail** (`TaskDetailPage`) — lifecycle actions only for open statuses
  (`Start`/`Complete`/`Cancel task`); terminal tasks hide lifecycle actions but
  keep `Edit`/`Delete`. Each action disables itself and shows its own spinner
  while in flight. Mutations apply the returned version, set a
  mutated-flag so the list refreshes on back, and confirm via snackbar. Delete
  confirms via dialog and shows `Task deleted.` before popping.
- **Form** (`TaskFormPage`) — shared create/edit. Create normalizes a blank
  description to `null`; edit computes a minimal PATCH (`_buildPatch`) with the
  explicit-null clear marker, and reports `No changes to save` when nothing
  changed. Title/description validators mirror backend limits (200 / 2000).
  Server 400 validation details map to inline field errors; everything else
  (including due-date validation) surfaces as a non-technical banner.

## Error handling

`TaskErrorCopy` never leaks backend internals. Transport failures get friendly
copy (network / timeout), 5xx → generic server message, known codes → tailored
copy (`TASK_NOT_FOUND`, `INVALID_TRANSITION`, `OPTIMISTIC_LOCK_CONFLICT`), plus
401 session-expired and 403 permission copy. On detail, `INVALID_TRANSITION` and
`OPTIMISTIC_LOCK_CONFLICT` snackbars add a **Refresh** action that reloads the
row (the optimistic-lock recovery path — no destructive auto-retry).

## Testing

- `test/features/tasks/task_models_test.dart` (15) — wire parsing, calendar-date
  handling, status fallbacks, lifecycle helpers, pagination, date formatters.
- `test/features/tasks/task_list_query_test.dart` (14) — defaults, exact
  query-param serialization (including omitting `overdue=false` / blank search),
  `copyWith` clear semantics, `resetPage`/`clearFilters`, active-filter
  accounting, and equality/hashCode consistency for calendar-day dates.
- `test/features/tasks/task_api_test.dart` (24) — request paths, bounded
  pagination/filter params, `listTasksFromQuery` wiring for search, status,
  overdue and inclusive due-date bounds, full-PUT / minimal-PATCH
  serialization, explicit-null clears, dedicated status/complete/cancel/delete
  endpoints, error surfacing (`TASK_NOT_FOUND`, `OPTIMISTIC_LOCK_CONFLICT`,
  `INVALID_TRANSITION`, validation details).
- `test/features/tasks/tasks_page_test.dart` (48) — loading/error/empty/refresh/
  filter/pagination states, debounced search + coalescing + clear, combined
  filter-sort interactions (including page reset), the due-date sheet flow
  (pick, clear, invalid range), create/edit/delete flows incl. confirmation +
  decline paths, patch diffing, lifecycle transitions, safe error copy,
  responsive no-overflow across 390/768/1280, and a11y semantics checks.

The fake backend (`test/support/mock_api.dart`) serves the same fixtures as the
dashboard tests and adds task-write state: a mutable `_tasks` store, per-endpoint
request counters, configurable failures, and id generation for created tasks. It
also implements the Phase 14 query contract — case-insensitive `search` across
title/description, inclusive `dueDateFrom`/`dueDateTo`, and sorting by any
allowlisted field in either direction — so widget/API tests exercise the real
server-backed behaviour.