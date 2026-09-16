## Phase 7 — Final Report

**1. Implemented features** — Advanced task listing + dashboard statistics API, on top of Phase 6 CRUD: paginated/filterable/sortable/searchable `GET /api/v1/tasks` and owner-scoped `GET /api/v1/dashboard`. Backend-only, no Flutter, no auth changes.

**2. `GET /api/v1/tasks` query parameters** — `page`(0), `size`(20, max 100 via `app.tasks.max-page-size`/`TASKS_MAX_PAGE_SIZE`), `sort`(createdAt), `direction`(DESC), `status`, `dueDateFrom`, `dueDateTo`, `overdue`, `search`. All optional; blank = absent.

**3. Pagination** — Zero-based, `PageRequest.of(page, size, sort)`; response wraps Spring Data `Page` metadata in `TaskPageResponse` (`content`, `page`, `size`, `totalElements`, `totalPages`, `first`, `last`).

**4. Filtering** — Single `status` (TODO/IN_PROGRESS/COMPLETED/CANCELLED; `OVERDUE` explicitly rejected); inclusive `dueDateFrom…dueDateTo` range over tasks that have a due date; `overdue` boolean filter; all combined with AND.

**5. Search** — Case-insensitive substring over `title` OR `description` using `lower()` + escaped `LIKE`; `%`, `_`, `\` are literal; pattern is lowercased so mixed-case input matches; ≤ 200 chars.

**6. Sorting** — Hard allowlist `{createdAt, updatedAt, dueDate, title, status}` (rejects `userId`, `overdue`, unknown); `direction` ASC/DESC; secondary `id ASC` tie-breaker for deterministic pagination; validation-message ordering is deterministic via `List.of`.

**7. Overdue implementation** — Derived, never persisted: `dueDate < LocalDate.now(clock)` AND status ∈ {TODO, IN_PROGRESS}; `overdue=false` includes tasks with no due date; same Clock as the per-task `overdue` flag; filter + dashboard counter stay consistent.

**8. Dashboard endpoint** — `GET /api/v1/dashboard` (new `ApiPaths.DASHBOARD`, authenticated route added in `SecurityConfig`) → `DashboardResponse` with `totalTasks`, `todoTasks`, `inProgressTasks`, `completedTasks`, `cancelledTasks`, `overdueTasks`.

**9. Repository/query architecture** — `TaskRepository` now extends `JpaSpecificationExecutor`; `TaskSpecifications.forUserAndFilters` builds the owner-scoped `WHERE` (ownership is always the first conjunct); `countDashboard` is a single JPQL aggregate with `coalesce(sum(case …),0)`.

**10. Security / IDOR** — No query param can cross user boundaries (owner conjunct in every spec/aggregate); cross-user filter/search asserted in ITs; invalid params → 400 `VALIDATION_ERROR` with field details (never clamped/ignored); dashboard exposes only 6 counts.

**11. Database / migrations** — No schema change; no new Flyway migration (existing `idx_tasks_user_status`, `idx_tasks_user_due_date` cover all Phase 7 paths). One entity fix in `Task` (`@PrePersist` aligns `completedAt` to the audited `createdAt` for tasks created as COMPLETED, satisfying `ck_tasks_completed_at_not_before_created`).

**12. DTOs added/updated** — `TaskListQuery` (raw strings), `TaskQueryFilters` (parsed), `TaskPageResponse`; `DashboardCounts`, `DashboardResponse`. `TaskResponse` unchanged.

**13. Controller/API surface** — `TaskController.listTasks` takes the 9 params with `@Parameter` docs; `DashboardController` added. `OpenApiConfig` description updated (task + dashboard implemented).

**14. Unit tests** — `TaskServiceTest` 55 (defaults, sort capture, mapping, all list-validation fields, blank filters, overdue values, combined violations; create-set tests updated for the new constructor), `DashboardServiceTest` 4.

**15. Integration tests** — `TaskApiIT` +~15 list/query tests (filters, range, search+escaping, pagination slices, sorts, overdue true/false, invalid params, cross-user isolation; existing list assertions updated to the paginated shape); new `DashboardApiIT` 6 tests (401, zero, mixed counts, completed/cancelled never overdue, per-user isolation, no userId exposed). `seedTask` seeds COMPLETED with `completedAt`.

**16. Exact results** — `.\mvnw.cmd -B clean verify`: unit 130/130, integration 133/133, **263 tests, 0 failures, BUILD SUCCESS** (1:42 min). Paired TaskApiIT+DashboardApiIT runs remained green across 3 consecutive runs after the INSERT-race and search-case fixes. No lint step exists for this Maven project.

**17. Docker verification** — `docker compose config --quiet` → OK (PostgreSQL compose unchanged).

**18. Issues/deviations** — (a) Latent Phase 6 race: creating a COMPLETED task could 409 (service `completedAt` < audit `createdAt`); fixed via `Task@PrePersist` alignment — surfaces deterministically, now covered by ITs. (b) Search pattern was not lowercased (only the column was); fixed. (c) `seedTask` helpers changed to resolve the owner by username (TokenResponse carries no userId).

**19. Confirmation** — No Phase 8+/Flutter work, no auth-architecture changes, no commit performed. Stopping.

**Docs updated:** `README.md`, `docs/api-overview.md` (§1d listing, §1e dashboard, §3), `docs/architecture.md` (§3.3a/3.4, §6.3/6.8, §6a, §7), `docs/security.md` (§8d listing/dashboard authz, non-goals).