# features/dashboard

Dashboard feature module (Phase 12).

## Overview

`/dashboard` renders the authenticated user's task overview using **real
backend data only**:

- **`GET /api/v1/dashboard`** — owner-scoped aggregate counters
  (`totalTasks`, `todoTasks`, `inProgressTasks`, `completedTasks`,
  `cancelledTasks`, `overdueTasks`), computed server-side from the caller's
  rows. The client never sends a user id.
- **`GET /api/v1/tasks`** — bounded preview pages driven by the existing
  Phase 7 query capabilities. No unbounded downloads: recent (10, sorted
  `createdAt DESC`), overdue (≤ 5, `overdue=true`), upcoming (≤ 5,
  `dueDateFrom=today`, `dueDate ASC`).

## Architecture

```
features/dashboard/
├── data/          → dashboard_api.dart (DashboardApi over ApiClient)
├── domain/        → dashboard_models.dart (DashboardSummary, DashboardTask,
│                     DashboardTaskStatus, DashboardTaskPage)
└── presentation/  → dashboard_page.dart (DashboardPage + private widgets)
```

All requests flow through `AppScope.apiOf(context)` — the authenticated
`ApiClient` built by `AuthState`, so every request carries the bearer token and
benefits from the transparent 401 → refresh → retry cycle. No second
authentication mechanism and no token handling lives in dashboard code.

## Domain models

- `DashboardSummary` — the six counters from `DashboardResponse` plus derived
  helpers (`openTasks`, `hasTasks`, `hasOverdue`, `countFor`, `fractionFor`).
- `DashboardTaskStatus` — the four persisted statuses (`TODO`, `IN_PROGRESS`,
  `COMPLETED`, `CANCELLED`). `OVERDUE` is deliberately absent: it is a derived
  flag, never a persisted status.
- `DashboardTask` — a list-row task (id, title, description, status, dueDate,
  completedAt, overdue, createdAt, updatedAt). `overdue` mirrors the backend's
  derived flag (past dueDate, not completed/cancelled).
- `DashboardTaskPage` — the paginated `TaskPageResponse` envelope.

## Presentation

`DashboardPage` is a `StatefulWidget` that owns all dashboard state via
`setState` (the same lightweight approach as Phase 11 — no new state package):

- **Loading** — full-screen `AppLoading` on first load (no zero-value flashes).
- **Metric cards** — responsive 1/2/3-column grid of the six counters, each a
  `Semantics`-labeled tile (`label, count`), so screen readers read the value
  once (child text semantics are excluded to avoid duplicate announcements).
- **Status distribution** — four native status bars (label + count + a
  proportional fill) rendered with Flutter primitives only — no chart package.
- **Overdue** — danger-tinted card listing overdue tasks with title, status,
  due date and an "Overdue" badge; a positive empty state when caught up.
- **Tasks** — bounded `Recent` (createdAt DESC) and `Coming up`
  (`dueDateFrom=today`) previews with optional status / overdue-only filter
  chips and a "View all tasks" affordance that navigates to `/tasks`. Task
  rows show title, status · due date, and a concise one-line description when
  the backend provides one.
- **Refresh** — app-bar refresh keeps the current content visible, shows a
  thin progress line, and prevents overlapping refreshes; failures surface a
  snackbar and keep the existing data.
- **Error** — `AppErrorState` with a Retry action. Messages are safe,
  status-aware copy (403 permission, 404, 500 generic, session-expired for a
  surfaced 401, backend message for 400/422 validation); backend detail never
  leaks to the screen.

Requests for the four sections run in parallel via `Future.wait`
(`eagerError: true`) — `eagerError` keeps the `ApiException` raw so error
mapping can classify the real failure.

## Responsive behavior

- **Compact (< 600)** — one-column metric cards, stacked sections, no
  horizontal scrolling.
- **Tablet (600–1023)** — two-column metrics, stacked content sections.
- **Desktop (≥ 1024)** — three-column metrics, capped 1200-lpx content width
  via `ResponsiveContainer`; the shell sidebar stays pinned.
- Layout decisions flow from actual `LayoutBuilder` constraints, never
  hardcoded viewport sizes.

## Testing

- `test/features/dashboard/dashboard_models_test.dart` — wire-contract parsing,
  status mapping (incl. `OVERDUE → null`), pagination, empty pages.
- `test/features/dashboard/dashboard_api_test.dart` — request paths, bounded
  pagination/filter parameters, error mapping.
- `test/features/dashboard/dashboard_page_test.dart` — loading/error/empty/
  refresh/filter/navigation states, metric semantics, responsive no-overflow
  checks across 390/768/1024/1280/1440.

The fake backend (`test/support/mock_api.dart`) serves the same `mockTasks` /
`mockDashboard` fixtures and can be configured to fail dashboard/tasks with a
specific status, code and message, or to delay responses while probing refresh
deduplication.