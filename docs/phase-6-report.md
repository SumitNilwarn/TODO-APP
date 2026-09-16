# Phase 6 — Task Management Backend: Implementation Report

## 1. Scope / decisions mandated by the task
- Implemented exactly the Phase 6 task-management backend on top of Phases 1–5 (Java 21, Spring Boot 3.5, PostgreSQL 16). No Phase 7 work (dashboard, filter/search/pagination), no Flutter changes, **no DB migration** (the Phase 3 `Task` schema from `V3`/`V4` already covers everything), no code committed.

## 2. What was implemented
New files under `backend/src/main/java/com/todoapp/`:
- **DTOs** (`dto/task/`): `TaskResponse`, `CreateTaskRequest`, `UpdateTaskRequest`, `UpdateTaskStatusRequest`, `TaskPatchRequest` + `TaskPatchValue` + `TaskPatchValueDeserializer` (presence-tracking partial updates).
- **Exceptions** (`exception/`): `TaskNotFoundException` (404 `TASK_NOT_FOUND`), `InvalidTaskTransitionException` (409 `INVALID_TRANSITION`).
- **Service** (`service/TaskService.java`): create/read/full-replace/patch/delete/list + status lifecycle, ownership-scoped queries, server-controlled `completedAt`, derived `overdue`, `saveAndFlush` for atomic audit fields.
- **Controller** (`controller/TaskController.java`): all 9 endpoints with `@Tag`/`@Operation`/`@ApiResponses` OpenAPI annotations.

Modified: `controller/ApiPaths.java` (`TASKS = "/api/v1/tasks"`), `security/config/SecurityConfig.java` (`/api/v1/tasks/** → authenticated`).

New/changed tests: `service/TaskServiceTest.java` (38), `dto/task/TaskPatchRequestJsonTest.java` (3), `TaskApiIT.java` (29, Testcontainers PostgreSQL 16).

## 3. Endpoints delivered (all authenticated)
`POST /api/v1/tasks`, `GET /api/v1/tasks/{taskId}`, `PUT /api/v1/tasks/{taskId}`, `PATCH /api/v1/tasks/{taskId}`, `DELETE /api/v1/tasks/{taskId}`, `PATCH .../status`, `PATCH .../complete`, `PATCH .../cancel`, `GET /api/v1/tasks`.

## 4. DTOs and validation
- **Create/PUT**: `title` required non-blank ≤200 (trimmed), `description` optional ≤2000 (blank rejected), `status` (default `TODO`; `@NotNull` on PUT), `dueDate` optional `yyyy-MM-dd`.
- **PATCH**: sparse via `TaskPatchValue` — omitted = untouched, explicit `null` = clear (`description`/`dueDate`), value = set; blank/unknown/`OVERDUE` rejected.
- **`completedAt`, `version`, `userId`, user-scoped selection** are never accepted from the client (unknown fields silently ignored; never trusted).

## 5. Service / controller / repository changes
- **Ownership / IDOR**: every operation resolves via `taskRepository.findByTaskIdAndUserId(taskId, userId)` with the `AuthenticatedUser` principal. A missing id and a foreign id return the identical `404 TASK_NOT_FOUND` — no enumerable task-id space leak, no cross-user reads/writes/deletes. Request body never carries an owner id; no user-scoped list endpoints.
- **Lifecycle rules** centralised in a transition map: `TODO → IN_PROGRESS / COMPLETED / CANCELLED`, `IN_PROGRESS → COMPLETED / CANCELLED`, `COMPLETED`/`CANCELLED` terminal. **Invalid transition → 409 `INVALID_TRANSITION`** with no state change; same-status on terminal states is an idempotent no-op. `OVERDUE` rejected as a status by DTO + service.
- New repo method (`findByTaskIdAndUserId`) is the only repository change.

## 6. Security model / authorization
- All `/api/v1/tasks/**` routes behind the existing `anyRequest().authenticated()` chain + `ACTIVE`-account filter. Ownership re-checked in the service on every operation. DTO-only serialization (`TaskResponse`); only the caller's tasks ever visible. Defense in depth: DI + DB scoping + service re-check.

## 7. Transition rules / `completedAt` behavior
- Transition table implemented in `TaskService` (see §5). `completedAt` is set strictly from the injected `Clock` when a task **becomes `COMPLETED`** (preserved on idempotent re-complete), cleared on any other status (including `CANCELLED`), satisfying the DB invariant `completed ⇔ completed_at` enforced by the `V4` `CHECK` constraint.

## 8. Overdue derivation / response
- `TaskResponse.overdue` = `dueDate != null && dueDate < LocalDate.now(clock)` (UTC) and status is `TODO`/`IN_PROGRESS`. Computed at response time, **never persisted**, never accepted as an input status. Completing/cancelling an overdue task flips it to `false`.

## 9. Database / Flyway changes
- **None** — the existing `tasks` table (`V3`) and `V4` constraints already model everything (statuses, `completed ⇔ completed_at`, `completed_at ≥ created_at`, `version`). `ddl-auto: validate` still passes, and migration `V4` is the latest.

## 10. Optimistic locking
- Reuses the entity `@Version` field; conflicts surface as `409 OPTIMISTIC_LOCK` via the existing handler. Verified in tests (two concurrent updates → 409).

## 11. Logging / correlation
- No changes required: `CorrelationIdFilter` + MDC cover the new endpoints automatically; task errors flow through the existing `GlobalExceptionHandler` with the same envelope/`X-Correlation-Id` behavior.

## 12. Tests written / results
- `TaskServiceTest` (38), `TaskPatchRequestJsonTest` (3), `TaskApiIT` (29, real PostgreSQL 16 via Testcontainers: CRUD, lifecycle, 401, disabled/locked, cross-user 404, spoofed `userId`/`completedAt`, overdue derivation & `OVERDUE` rejection, idempotency, database CHECKs).
- Full build: **`mvnw clean verify` → BUILD SUCCESS**; **112 tests, 0 failures, 0 skips**, including all Phases 1–5. `docker compose config --quiet` in `infrastructure/` → **OK**.

## 13. Docs updated
- `README.md` (status banner → Phase 6, docs links), `docs/api-overview.md` (new §1c Task endpoints: routes, field matrix, lifecycle, `completedAt`/`overdue`, `TASK_NOT_FOUND`/`INVALID_TRANSITION`, status model, OpenAPI), `docs/architecture.md` (scope banner, new §3.3 Task management service, §6a communication), `docs/security.md` (new §8c Task authorization & ownership, Phase 6 non-goals).

## 14. Issues / deviations
- Swagger's `@ApiResponse` collides with `com.todoapp.dto.ApiResponse` for Javadoc-only references — resolved with fully-qualified names (retaining the `@` prefix), no runtime impact.
- One weak early assertion in `TaskApiIT` (enum-vs-string `isNotEqualTo("OVERDUE")`) replaced with an exact `TaskStatus.COMPLETED` assertion.
- No other deviations; all listed endpoints, rules and safety properties implemented as specified.

## 15. Boundary of this phase — what was deliberately NOT done
- No Phase 7 work: no dashboard/stats, **no filter/search/sort/pagination** on `GET /api/v1/tasks` (basic list only), no `OVERDUE` as a stored status, no shared/public tasks, no admin task APIs, no notifications. No changes under `frontend/` (git shows zero frontend diffs). Nothing was committed (repo tree remains untracked by design).

## 16. Next steps
- **Where to operate from:** proceed with Phase 7 (likely list query expansion → dashboard → Flutter integration) when ready. The `GET /api/v1/tasks` endpoint is deliberately decoupled from pagination so it can evolve without breaking the Phase 6 contract.
- **To run what was verified:** from `backend/`, `$env:JAVA_HOME="C:\Users\Sumit\.jdks\ms-21.0.12.1"; .\mvnw.cmd -B clean verify`; from `infrastructure/`, `docker compose config --quiet`.

Phase 6 is complete, verified, and fully scoped. Stopping here.