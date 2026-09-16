# API Overview

This document records the REST API conventions for the Todo App.

> **Status:** the **authentication**, **profile**, **task management**,
> **task listing** and **dashboard** endpoints are implemented (Phases 4–7):
> `POST /api/v1/auth/register|login|refresh|logout`,
> `GET /api/v1/auth/me`, `GET/PUT/PATCH /api/v1/profile`, the health endpoints,
> `POST/GET/PUT/PATCH/DELETE /api/v1/tasks`, the task lifecycle endpoints,
> the paginated/filterable/sortable/searchable `GET /api/v1/tasks` list, and
> `GET /api/v1/dashboard`. See [security.md](security.md) for the full
> auth/security design. The backing domain model (User, UserProfile, Task,
> RefreshToken) and schema (Flyway `V1`–`V4`) are implemented (Phase 3–4).

## 1. Conventions

- **Base path:** all endpoints are prefixed with `/api/v1` (constant
  `ApiPaths.V1`).
- **JSON** request/response bodies using UTF-8.
- **DTOs (records) define the contracts.** JPA entities are never serialized.
- **Stateless** API authenticated with a Bearer JWT (Phase 4, see
  [security.md](security.md)); only `register`, `login`, `refresh`, `logout`
  (all `POST /api/v1/auth/*`) and `/api/v1/health/**` are public — everything
  else, including `GET /api/v1/auth/me`, requires a valid access token.
- Controllers are thin; services own business logic.
- Every successful response uses the `ApiResponse` envelope; every error uses
  the `ApiError` envelope (below).

### Implemented endpoints

| Resource        | Endpoints (implemented)                              |
| --------------- | ----------------------------------------------------- |
| Health          | `GET /api/v1/health`, `GET /api/v1/health/readiness` |
| Authentication  | `POST /api/v1/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `GET /api/v1/auth/me` |
| Profile         | `GET /api/v1/profile`, `PUT /api/v1/profile`, `PATCH /api/v1/profile` |
| Tasks           | `GET/POST /api/v1/tasks`, `GET/PUT/PATCH/DELETE /api/v1/tasks/{taskId}`, `PATCH /api/v1/tasks/{taskId}/status`, `PATCH /api/v1/tasks/{taskId}/complete`, `PATCH /api/v1/tasks/{taskId}/cancel` |
| Dashboard       | `GET /api/v1/dashboard`                              |

### Planned resources and endpoint shapes

| Resource        | Planned endpoints                            |
| --------------- | -------------------------------------------- |
| —               | None currently planned. Task queries and the dashboard were the last scheduled backend features (Phase 7). |

Any future feature must follow the same envelope, validation and
owner-scoping conventions documented here before it is shipped.

## 1b. Profile endpoints (implemented, Phase 5)

The profile is a **private, caller-owned** resource: there are no profile-list
endpoints and no `{id}` path segment. The owner is always derived from the
authenticated principal in the access token — the request body never carries
(or is never trusted to carry) a user id.

| Endpoint                              | Auth | Description |
| ------------------------------------- | ---- | ----------- |
| `GET /api/v1/profile`                 | Bearer | Returns the caller's profile. `404 PROFILE_NOT_FOUND` if none exists yet. |
| `PUT /api/v1/profile`                 | Bearer | **Full replacement / upsert.** All five fields are replaced by the body; `null` clears a field. `201` when a profile is created, `200` otherwise. |
| `PATCH /api/v1/profile`               | Bearer | **Partial update.** Only fields present in the body are changed: an explicit JSON `null` clears a field, an omitted field is left untouched, `{}` is a no-op. `404` if no profile exists. |

Profile fields (all optional; a fully empty profile is allowed):

| Field            | Limits                        | Notes                                        |
| ---------------- | ----------------------------- | -------------------------------------------- |
| `firstName`      | ≤ 50 chars                    | `null` clears; blank rejected                |
| `lastName`       | ≤ 50 chars                    | `null` clears; blank rejected                |
| `displayName`    | ≤ 100 chars                   | `null` clears; blank rejected                |
| `timezone`       | ≤ 64 chars                    | must be an IANA timezone id (`UTC`, `GMT`, `US/Eastern`, …) |
| `profileImageUrl`| ≤ 255 chars                   | must be an absolute `http(s)` URL            |

Semantics/conventions:

- Values are **trimmed** before persistence (e.g. `" Europe/London "` is stored
  as `Europe/London`).
- Clearing a field with a blank string is rejected with `400 VALIDATION_ERROR`
  (no accidental whitespace-only values); clearing requires JSON `null`.
- Responses use the `ApiResponse` envelope with a `data` payload shaped like
  `ProfileResponse`: `userId`, `firstName`, `lastName`, `displayName`,
  `timezone`, `profileImageUrl`, `createdAt`, `updatedAt`, `version`.
- **Optimistic locking:** the server applies JPA `@Version` optimistic locking
  internally (the response `version` starts at `0` and increments on every
  change). Two *overlapping* server-side write transactions on the same profile
  surface as `409 OPTIMISTIC_LOCK_CONFLICT`. The API never accepts a
  client-supplied version, so a *non-overlapping* stale write (the row was
  already changed by another writer) is applied last-writer-wins and is not
  detectable from client-supplied input.

## 1c. Task endpoints (implemented, Phase 6)

The task API is a **private, caller-owned** resource: ownership is always
derived from the authenticated principal in the access token. The request body
never carries (or is never trusted to carry) a user id, and there are no
user-scoped list endpoints. A task that is missing — **or belongs to another
user** — is reported as the same `404 TASK_NOT_FOUND`, so the API never leaks
whether another user's task exists. All task endpoints are authenticated.

| Endpoint                          | Auth   | Description |
| --------------------------------- | ------ | ----------- |
| `POST /api/v1/tasks`              | Bearer | Create a task owned by the caller. Status defaults to `TODO`. Returns `201`. |
| `GET /api/v1/tasks/{taskId}`      | Bearer | Return the caller's task. |
| `PUT /api/v1/tasks/{taskId}`      | Bearer | **Full replacement.** `title` + `status` are required; `description`/`dueDate` may be `null` (cleared). `createdAt` is preserved. |
| `PATCH /api/v1/tasks/{taskId}`    | Bearer | **Partial update.** Only present fields change; explicit `null` clears `description`/`dueDate`; `{}` is a no-op. |
| `DELETE /api/v1/tasks/{taskId}`   | Bearer | Delete the caller's task. Returns `200` + `"Task deleted"`. |
| `PATCH /api/v1/tasks/{taskId}/status` | Bearer | Set the status, enforcing lifecycle rules. Body: `{"status":"IN_PROGRESS"}`. |
| `PATCH /api/v1/tasks/{taskId}/complete` | Bearer | Mark `COMPLETED`, stamping `completedAt` from the server clock. |
| `PATCH /api/v1/tasks/{taskId}/cancel`   | Bearer | Mark `CANCELLED` and clear any `completedAt`. |
| `GET /api/v1/tasks`               | Bearer | List the caller's tasks with pagination, filters, search and sorting (Phase 7). See §1d below. |

Task fields accepted on writes (per endpoint):

| Field         | POST | PUT | PATCH | Limits / notes |
| ------------- | ---- | --- | ----- | -------------- |
| `title`       | ✓    | ✓   | ✓     | required, non-blank, ≤ 200 chars, trimmed |
| `description` | ✓    | ✓   | ✓     | optional, ≤ 2000 chars; `null` clears; blank rejected |
| `status`      | opt  | ✓   | ✓     | default `TODO`; one of `TODO`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `dueDate`     | ✓    | ✓   | ✓     | optional ISO-8601 date (`yyyy-MM-dd`); `null` clears |
| `completedAt` | ✗    | ✗   | ✗     | **never accepted** — always computed server-side |
| `userId`      | ✗    | ✗   | ✗     | **never accepted** — ownership always from the JWT principal |

Unknown request fields (including `completedAt` and `userId`) are ignored,
never trusted.

### Lifecycle rules

Every task starts as `TODO`. The allowed transitions are:

- `TODO` → `TODO` (no-op), `IN_PROGRESS`, `COMPLETED`, `CANCELLED`
- `IN_PROGRESS` → `IN_PROGRESS` (no-op), `COMPLETED`, `CANCELLED`
- `COMPLETED` → `COMPLETED` (idempotent no-op) — terminal, cannot be reopened
- `CANCELLED` → `CANCELLED` (idempotent no-op) — terminal, cannot be completed/reopened

A transition outside this table returns `409 INVALID_TRANSITION` with no state
change. `OVERDUE` is **not** a status and is rejected if sent as one.

### `completedAt` behaviour

- `completedAt` is always set from the **application clock at the moment the
  task becomes `COMPLETED`** — never from the client.
- Completing already-`COMPLETED` tasks is idempotent and preserves the original
  `completedAt`.
- Any status other than `COMPLETED` (including `CANCELLED`) clears
  `completedAt` to `null`, matching the database `CHECK`
  (`completed` ⇔ `completed_at IS NOT NULL`).

### `overdue` derivation

`TaskResponse.overdue` is **derived at response time** and never persisted:

```
overdue = dueDate != null && dueDate < today && status ∉ {COMPLETED, CANCELLED}
```

"today" is the current calendar date of the injected application `Clock`
(UTC). Completing/cancelling an overdue task flips the flag to `false`.

`TaskResponse` shape: `id`, `title`, `description`, `status`, `dueDate`,
`completedAt`, `overdue`, `createdAt`, `updatedAt`, `version`. JPA entities,
password hashes and account data are never serialized.

## 1d. Task listing query parameters (implemented, Phase 7)

`GET /api/v1/tasks` paginates and filters the **caller's** tasks. Ownership
scoping is unchanged: the principal's id is always part of the query, so
another user's tasks can never appear in the result regardless of the
parameters supplied. All unknown/unsupported values are rejected with
`400 VALIDATION_ERROR` and a structured `details` array — never silently
ignored.

| Parameter     | Type     | Default     | Max/limits            | Notes |
| ------------- | -------- | ----------- | --------------------- | ----- |
| `page`        | integer  | `0`         | –                     | zero-based page index; negative rejected |
| `size`        | integer  | `20`        | `100` (configurable via `app.tasks.max-page-size`) | must be ≥ 1; over-limit rejected (not clamped) |
| `sort`        | string   | `createdAt` | –                     | allowlist: `createdAt`, `updatedAt`, `dueDate`, `title`, `status`; anything else rejected (`userId`, `done`, `overdue`, …) |
| `direction`   | string   | `DESC`      | –                     | only `ASC` or `DESC` |
| `status`      | string   | –           | –                     | one of `TODO`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`; `OVERDUE` is rejected (it is derived, not a status) |
| `dueDateFrom` | date     | –           | –                     | inclusive lower bound, ISO-8601 `yyyy-MM-dd` |
| `dueDateTo`   | date     | –           | –                     | inclusive upper bound; `dueDateFrom` must not be after `dueDateTo` |
| `overdue`     | boolean  | –           | –                     | `true`/`false`; filters on the derived overdue rule (see §4) |
| `search`      | string   | –           | 200 chars             | case-insensitive partial match over `title` or `description`; `%`, `_`, `\` are treated literally (escaped) |

Semantics:

- Blank values act as if the parameter was absent, so repeated/optional query
  strings stay clean; values are trimmed.
- `dueDate` range matches are inclusive and only apply to tasks that actually
  have a due date (a `null` due date never matches a range).
- `overdue=false` includes every task that is **not** overdue — including tasks
  with no due date.
- `overdue=true` matches `dueDate < today` with status `TODO` or
  `IN_PROGRESS` only ("today" = the application `Clock` UTC date).
- `search` matches a substring of the title or the description
  case-insensitively; wildcard characters are escaped so user input is matched
  literally.
- Ordering is fully deterministic: the primary sort column+`direction` is
  applied and tied with an `id ASC` break, so pagination never skips or
  duplicates rows.

Response shape (`ApiResponse.data`):

```json
{
  "content": [ { "...": "each TaskResponse" } ],
  "page": 0,
  "size": 20,
  "totalElements": 123,
  "totalPages": 7,
  "first": true,
  "last": false
}
```

## 1e. Dashboard endpoint (implemented, Phase 7)

`GET /api/v1/dashboard` returns aggregate counters over the **caller's** tasks
only. It is a single owner-scoped aggregate query — no task rows are loaded
into memory. Response shape (`ApiResponse.data`):

```json
{
  "totalTasks": 13,
  "todoTasks": 5,
  "inProgressTasks": 3,
  "completedTasks": 3,
  "cancelledTasks": 2,
  "overdueTasks": 3
}
```

Semantics:

- `totalTasks` = everything owned by the caller.
- The four status counts sum to `totalTasks`.
- `overdueTasks` counts tasks that are overdue **today** with status `TODO` or
  `IN_PROGRESS` — `COMPLETED`/`CANCELLED` tasks are never overdue, exactly like
  the per-task `overdue` flag (same Clock-based rule as §4).
- No user ids or other users' data are exposed; no query parameters are
  accepted.

## 2. Response envelopes

### Success

```json
{
  "success": true,
  "data": { "...": "..." },
  "message": null
}
```

`data` carries the resource payload; `message` is optional (e.g. on created
resources).

### Error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      { "field": "dueDate", "message": "must not be null" }
    ]
  },
  "timestamp": "2026-01-01T00:00:00Z",
  "path": "/api/v1/..."
}
```

Semantics:

- `success` — `false` for all errors.
- `error.code` — stable machine-readable code (see below).
- `error.message` — human-readable summary.
- `error.details` — structured field-level violations (empty for most errors).
- `timestamp` — ISO-8601 UTC time of the failure.
- `path` — the request path that failed.

Error codes currently produced by the backend:

| Code                    | HTTP status | Meaning                                   |
| ----------------------- | ----------- | ----------------------------------------- |
| `VALIDATION_ERROR`      | 400         | Bean-validation or constraint violations  |
| `MALFORMED_REQUEST`     | 400         | Missing/malformed request body            |
| `INVALID_PARAMETER`     | 400         | Wrong-typed query/path parameter          |
| `ILLEGAL_ARGUMENT`      | 400         | Service-level illegal argument            |
| `BAD_REQUEST`           | 400         | Explicit bad request (`BadRequestException`) |
| `NOT_FOUND`             | 404         | Resource not found                        |
| `PROFILE_NOT_FOUND`     | 404         | Caller has no profile yet                  |
| `TASK_NOT_FOUND`        | 404         | Task missing or belongs to another user     |
| `INVALID_TRANSITION`    | 409         | Task status change violates lifecycle rules |
| `AUTHENTICATION_FAILED` | 401         | Wrong credentials / unknown account       |
| `TOKEN_EXPIRED`         | 401         | JWT access token expired                  |
| `TOKEN_INVALID`         | 401         | JWT missing, malformed or signature fails |
| `REFRESH_TOKEN_INVALID` | 401         | Refresh token not found (revoked or bad)  |
| `REFRESH_TOKEN_EXPIRED` | 401         | Refresh token past its expiry ceiling     |
| `ACCOUNT_DISABLED`      | 403         | Login attempted on a disabled account     |
| `ACCOUNT_LOCKED`        | 403         | Login attempted on a locked account       |
| `FORBIDDEN`             | 403         | Authenticated but missing required scope  |
| `OPTIMISTIC_LOCK_CONFLICT` | 409     | Version-based write conflict              |
| `CONFLICT`              | 409         | Data-integrity conflict (e.g. duplicate)  |
| `SERVICE_UNAVAILABLE`   | 503         | Required dependency (e.g. DB) unreachable |
| `INTERNAL_ERROR`        | 500         | Unexpected server failure (safe message)  |

Clients never receive stack traces, credentials or internal details; those are
logged server-side only.

## 3. Pagination, filtering, sorting (implemented)

- `GET /api/v1/tasks` returns a paginated, filterable, sortable, searchable
  page of the caller's tasks (Phase 7, see §1d). Validating the parameters is
  the service layer's job: invalid values produce `400 VALIDATION_ERROR` with
  field-level `details`.
- `page`, `size`, `sort`, `direction` — standard Spring Data-style pagination
  parameters, with a sort allowlist and a deterministic `id ASC` tie-breaker.
- Filters (`status`, `due-date` range, `overdue`, `search`) are explicit query
  parameters and combine with `AND`.
- The same `Page`-derived envelope is used for every list response, keeping the
  contract consistent.

## 4. Task status model

Two distinct concepts must not be confused:

**Persisted lifecycle state** (`tasks.status`, implemented in Phase 3):

| Status        | Meaning                    |
| ------------- | -------------------------- |
| `TODO`        | Not started                |
| `IN_PROGRESS` | Being worked on            |
| `COMPLETED`   | Finished (`completedAt` set) |
| `CANCELLED`   | Superseded / dropped       |

The database enforces exactly these four values via a `CHECK` constraint and
ties `COMPLETED` to a non-null `completed_at`.

**Derived state** `OVERDUE` (implemented, Phase 6):

- `OVERDUE` is deliberately **not** a stored status. It is computed at runtime
  when `dueDate` has passed and the task is neither `COMPLETED` nor
  `CANCELLED`, and exposed as the `overdue` flag on `TaskResponse`.
- The exact calculation uses the injected application `Clock` (UTC): a task is
  overdue when `dueDate != null && dueDate.isBefore(LocalDate.now(clock))` and
  its status is `TODO` or `IN_PROGRESS`.

## 5. Versioning

- Path versioning under `/api/v1`.
- Breaking changes introduce `/api/v2`; backwards-compatible additions keep the
  current version.

## 6. OpenAPI / Swagger

- The backend exposes generated OpenAPI docs:
  - UI: `GET /swagger-ui.html`
  - JSON: `GET /v3/api-docs`
- Schemas are derived from the DTO records.
- Auth endpoints (Phase 4), the profile endpoints (Phase 5), the task
  endpoints (Phase 6) and the listing + dashboard endpoints (Phase 7) are fully
  documented in OpenAPI via their controller annotations (`@Operation`,
  `@ApiResponses`, `@Tag`) and the Bearer security scheme.