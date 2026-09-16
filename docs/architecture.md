# Architecture

This document describes the target system architecture for the Todo App.

> **Phase 7 scope:** authentication is production-ready: stateless JWT access
> tokens (jjwt 0.12), BCrypt password hashing, rotated/persisted opaque refresh
> tokens with a hard expiry ceiling (`V4__create_refresh_tokens.sql`), logout and
> a fully wired Spring Security filter chain. Registration/login/refresh/logout
> and `/auth/me` endpoints exist under `/api/v1/auth`. The caller-owned user
> profile API (`GET/PUT/PATCH /api/v1/profile`, phase 5) reuses the same auth and
> needs no schema change (`user_profiles` from `V2`). Phase 6 adds the task
> management API (`/api/v1/tasks`, CRUD + lifecycle) on top of the existing
> `Task` entity (`V3`), with server-controlled `completedAt`, derived `overdue`
> and no schema change. Phase 7 adds the paginated/filterable/sortable/searchable
> task list (`GET /api/v1/tasks` query parameters) and the caller-scoped dashboard
> statistics endpoint (`GET /api/v1/dashboard`), both read-only and IDOR-safe,
> with **no schema or Flutter changes**. The remaining backend work is the
> Flutter integration.

## 1. System overview

```
┌──────────────────┐        HTTPS / JSON        ┌──────────────────────────────┐
│  Flutter client  │ ────────────────────────▶  │  Spring Boot REST API         │
│  (Web today,     │                            │  (layered architecture)       │
│   Android/iOS    │ ◀────────────────────────  │                               │
│   later)         │                            ├──────────────────────────────┤
└──────────────────┘                            │  Spring Security (foundation) │
                                                │  Controllers (thin)          │
                                                │  Services (business logic)    │
                                                │  Repositories (JPA)           │
                                                ├──────────────────────────────┤
                                                │  PostgreSQL                   │
                                                │  schema owned by Flyway      │
                                                └──────────────────────────────┘
```

- **Frontend**: Flutter, currently targeting **Web only**. The same Dart
  business/domain/data code will be reused for future Android and iOS builds.
- **Backend**: Spring Boot, exposing a REST API. It is the **single source of
  truth** for task state (`TODO`, `IN_PROGRESS`, `COMPLETED`, `OVERDUE`,
  `CANCELLED` behaviour will be enforced server-side in later phases).
- **Database**: PostgreSQL stores all persistent application data.
- **Schema ownership**: Flyway migrations own the schema. Hibernate **never**
  auto-creates or alters production tables (`ddl-auto` is `validate`).

## 2. Frontend / backend separation

- The two modules are **strictly decoupled** and communicate only through the
  HTTP/JSON REST contract.
- The Flutter client never reaches the database; it talks to the backend API.
- The API base URL is injected at build/run time via
  `--dart-define=API_BASE_URL=...` — see `frontend/lib/core/config`.

## 3. Backend layers

Layered packages under `com.todoapp`:

```
com.todoapp
├── controller/    # Thin HTTP controllers — no business logic
├── service/       # Business logic / use cases (incl. auth, jwt, password, refresh)
├── repository/    # Spring Data JPA repositories
├── entity/        # JPA entities + domain enums (User, UserProfile, Task, RefreshToken, ...)
├── dto/           # API request/response records (the API contract)
├── mapper/        # Entity <-> DTO mapping
├── security/      # Spring Security (config/, filter/, principals, 401/403 writers)
├── exception/     # ApiException hierarchy + GlobalExceptionHandler + auth exceptions
├── configuration/ # OpenAPI, CORS, correlation/logging, JPA auditing, JwtConfig, ... beans
└── TodoApplication
```

Rules:

- **Controllers stay thin**: they parse input, call a service and map the
  result; no business logic lives in controllers.
- **DTOs are the only API contract**: JPA entities are never exposed through
  REST endpoints. Json views/mappers live in `mapper`.
- **Services hold business logic** and are independently unit-testable.
- **Repositories** are Spring Data JPA interfaces.

### Transactions

- Transaction boundaries live at the **service layer** via `@Transactional`
  on public service methods that mutate multiple aggregates.
- Read-only queries use `@Transactional(readOnly = true)`.
- Controllers, repositories and mappers never declare transactions.
- Auth flows (`AuthService`, `RefreshTokenService`) are transactional: a login
  that fails account checks rolls back the whole change (e.g. `lastLoginAt` or
  a consumed refresh token), and races on duplicate accounts are caught as
  `DataIntegrityViolationException` and mapped to `ACCOUNT_ALREADY_EXISTS`.

## 3.1 Authentication & security

Implemented in Phase 4. The full threat model, token lifecycle and operational
checklist live in [security.md](security.md). Summary:

- **BCrypt** password hashing (`PasswordService`); plaintext never persisted,
  serialized or logged.
- **JWT access tokens** (HS256, jjwt 0.12): identity claims only (`sub`, `iss`,
  `iat`, `exp`, `username`); signature/issuer/expiry validated on every
  protected request; 900s default lifetime (`JWT_ACCESS_TOKEN_EXPIRATION`).
- **Opaque refresh tokens** (256-bit random, base64url): only the SHA-256 hash
  is stored in `refresh_tokens`; single-use rotation on refresh; hard expiry
  ceiling that survives rotation (30-day default via `JWT_REFRESH_TOKEN_EXPIRATION`);
  revoked on logout and by `ON DELETE CASCADE` when the user is removed.
- **Security chain** (`security/config/SecurityConfig`, stateless): public
  static list = OPTIONS, the four public auth endpoints
  (`POST /auth/register|login|refresh|logout`), `/api/v1/health/**`, Swagger UI +
  `/v3/api-docs/**`; `anyRequest().authenticated()` (so `GET /api/v1/auth/me`
  and everything else needs a token). `JwtAuthenticationFilter`
  populates the `SecurityContext` for valid tokens and additionally requires an
  `ACTIVE` account. Filter-stage failures are rendered as the familiar
  `ApiError` envelope by `RestAuthenticationEntryPoint` (401) /
  `RestAccessDeniedHandler` (403).
- `last_login_at` is updated only on successful password login; DISABLED/LOCKED
  accounts are rejected at login, on refresh and per-request.

## 3.2 User profile service (Phase 5)

- `ProfileService` owns the profile use cases: read, full replace (PUT, upsert),
  and partial update (PATCH). All operations resolve the owner exclusively from
  the `AuthenticatedUser` principal — no id travels in the request.
- **Validation is two-tiered:** PUT keeps a declarative bean-validation contract
  on `ProfileUpdateRequest` (with `@NotBlankOrNull` "clear-via-null, reject
  blank" semantics), while PATCH validates the sparse input programmatically in
  the service (a field is either absent, a clear, or a value — the same rules
  apply). Both produce the same 400 `VALIDATION_ERROR` envelope with
  field-level details.
- **Shared custom constraints** live in `com.todoapp.validation`:
  `ValidTimezone` (IANA ids, `TimezoneValidator`), `ValidHttpUrl` (absolute
  `http(s)`, `HttpUrlValidator`), `NotBlankOrNull`. Values are trimmed before
  persistence.
- Mutations call `saveAndFlush` so auditing timestamps/`version` are populated
  in the response atomically; optimistic locking (6.5) is preserved.

## 3.3 Task management service (Phase 6)

- `TaskService` owns the task use cases: create, read, full replace (PUT),
  partial update (PATCH), delete, status transitions, list. Ownership is
  resolved on every operation from the `AuthenticatedUser` principal via
  `TaskRepository.findByTaskIdAndUserId(taskId, userId)` — no id travels in the
  request body, so task ids cannot be cross-referenced (IDOR-safe).
- **Lifecycle rules** are centralized in one transition map (`TODO →
  IN_PROGRESS/COMPLETED/CANCELLED`, `IN_PROGRESS → COMPLETED/CANCELLED`,
  `COMPLETED`/`CANCELLED` terminal). Violations raise
  `InvalidTaskTransitionException` → `409 INVALID_TRANSITION`. Same-status
  updates on terminal states are idempotent no-ops.
- **Server-controlled time:** `completedAt` is always set from the injected
  `Clock` bean when a task becomes `COMPLETED` (preserved on re-complete,
  cleared on any other status, enforced at the DB level by the `CHECK` from
  migration `V4`). The client can never supply it.
- **Derived state:** `overdue` is computed at response time
  (`dueDate < LocalDate.now(clock)` and not finished/terminal) by
  `TaskResponse`, not persisted. Invalid `OVERDUE` status input is rejected.
- **Validation is two-tiered** like the profile service: declarative
  bean-validation on `CreateTaskRequest`/`UpdateTaskRequest` (shared
  `NotBlankOrNull` "clear-via-null" semantics), programmatic on `PATCH` via the
  presence-tracking `TaskPatchValue` wrapper (mirrors `PatchField`). Blank
  titles/descriptions are rejected; `dueDate` must be a valid date.
- Mutations use `saveAndFlush` so auditing timestamps/`version` are returned
  atomically; optimistic locking (6.5) is preserved.

## 3.3a Task listing & filtering service (Phase 7)

- `TaskService.listTasks(principal, TaskListQuery)` is the single entry point
  for `GET /api/v1/tasks`. The controller passes raw String query parameters in
  a `TaskListQuery` record; the service parses and validates them on its side
  and raises the normal `FieldValidationException` → `400 VALIDATION_ERROR` with
  field-level `details` for any unsupported value (so the parsing rules live
  next to the business rules, consistent with the PATCH handling).
- **Implementation strategy:** `TaskRepository` extends
  `JpaSpecificationExecutor<Task>`; `TaskSpecifications.forUserAndFilters(...)`
  builds one JPQL `WHERE` that always starts with the owner conjunct
  (`user_id = principal`), then ANDs the optional filters — status, inclusive
  `dueDate` range, the derived `overdue` predicate, and a case-insensitive
  substring search over `title`/`description` whose `%`/`_`/`\` are escaped so
  input is matched literally. Sorting uses a hard allowlist
  (`createdAt`, `updatedAt`, `dueDate`, `title`, `status`) plus an `id ASC`
  tie-breaker for deterministic pagination. Overdue filtering uses the same
  injected `Clock` as the response-level flag, so both stay consistent.
- **Defaults and limits:** `page=0`, `size=20`, `sort=createdAt`,
  `direction=DESC`; the maximum page size is configurable
  (`app.tasks.max-page-size`, env `TASKS_MAX_PAGE_SIZE`, default `100`) and
  over-limit requests are rejected rather than clamped. Blank values are treated
  as absent.
- The response wraps the Spring Data `Page` metadata in a stable
  `TaskPageResponse` DTO (content + page/size/totalElements/totalPages/first/
  last).

## 3.4 Dashboard service (Phase 7)

- `DashboardService.getDashboard(principal)` runs a **single owner-scoped JPQL
  aggregate query** and returns `DashboardResponse`. Nothing materializes task
  rows.
- The query counts the caller's tasks by status and applies the same overdue
  rule as the list endpoint (`dueDate < today AND status IN (TODO, IN_PROGRESS)`
  with `today` from the injected `Clock`), computing overdue with
  `coalesce(sum(case when ... then 1 else 0 end), 0)`.
- `GET /api/v1/dashboard` (new `ApiPaths.DASHBOARD`) is registered as an
  authenticated route in `SecurityConfig`; the response exposes only the six
  counts.

## 4. Flutter architecture

Feature-first, clean-architecture-inspired layout under `frontend/lib`:

```
lib
├── core/            # Cross-cutting concerns (config, constants, network)
├── shared/          # Reusable presentation primitives (theme, widgets)
├── features/        # Feature modules, each with its own
│   └── <feature>/
│       ├── presentation/  # screens & widgets
│       ├── domain/        # entities, use cases, repositories (abstract)
│       └── data/          # repository implementations, DTOs, API client
├── presentation/    # App shell, routing, top-level widgets
├── domain/          # Global domain code shared across features
├── data/            # Global data/API plumbing shared across features
└── application/     # Application-level state management
```

Rationale:

- Rules point **inward**: `presentation` depends on `domain` (via abstract
  repository/use-case contracts), `data` implements those contracts.
- Because `domain` and `data` are platform-independent Dart, the **business
  logic is reused unchanged** when Android and iOS support is added — only the
  `web/`, `android/`, `ios/` platform shells differ.

### Android / iOS expansion strategy

When mobile support is added:

1. Add the platform shells (`flutter create . --platforms android,ios`).
2. Keep `lib/core`, `lib/features/*/domain`, `lib/features/*/data`,
   `lib/application` untouched.
3. Only presentation adaptations (e.g. responsive layouts, safe area,
   platform widgets) are layered on top.

## 5. PostgreSQL role

- PostgreSQL is the single persistent store (development instance runs in
  Docker Compose, see `infrastructure/`).
- Connection settings come from the environment:
  `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`.
- All schema evolution happens through versioned Flyway migrations in
  `backend/src/main/resources/db/migration`.
- Task-status rules (overdue behaviour, transitions) will be enforced by the
  backend service layer, with PostgreSQL as the source of truth.

## 6. Domain model & persistence design

The persistent domain layer (Phase 3) consists of three aggregates backed by the
Flyway migrations `V1`–`V3`. Full column inventory is in the migration SQL
(`backend/src/main/resources/db/migration`).

### 6.1 Entities and relationships

```
User ──1────1── UserProfile          (user_profiles.user_id → users.id, unique)
User ──1────N── Task                 (tasks.user_id → users.id)
User ──1────N── RefreshToken         (refresh_tokens.user_id → users.id, CASCADE)
```

- **`User`** holds only account/security data: `username`, `email`,
  `passwordHash`, `accountStatus`, `lastLoginAt`. Profile data is excluded.
- **`UserProfile`** holds profile data (`firstName`, `lastName`, `displayName`,
  `timezone`, `profileImageUrl`) and is the *owning* side of the 1:1. `User` has
  no back-reference, so no inverse lazy collection exists.
- **`Task`** belongs to exactly one `User` via a lazy, unidirectional
  `@ManyToOne`; there is no `tasks` collection on `User` (avoids accidental
  eager loading and large collections).
- **`RefreshToken`** is a session/credential row for one opaque login token
  (see 3.1 and 6.1.1). It stores only the token's SHA-256 hash.
- **Registering** is now possible via `POST /api/v1/auth/register` (Phase 4).

#### 6.1.1 Refresh token storage

- `refresh_tokens` stores one row per outstanding opaque refresh token:
  `token_hash` (SHA-256 hex, `UNIQUE`), `expires_at` (hard lifetime ceiling),
  `last_used_at`, `revoked_at`.
- `revoked_at <= last_used_at` is a database `CHECK`, so a token can only be
  revoked after (or at) first use — rotation semantics are DB-enforced.
- User deletion cascades (`fk_refresh_tokens_user ON DELETE CASCADE`); every
  session dies with its account.
- Only the hash is stored — a database leak does not expose usable tokens.

### 6.2 UUID strategy

- Every primary key is a **UUID generated by the application** (Hibernate
  `@UuidGenerator(style = RANDOM)`, i.e. UUID v4) and stored in a PostgreSQL
  `uuid` column. IDs are created on persist, so they are available before flush
  and are safe to expose in future API URLs without leaking ordering info.
- Trade-off (documented): random UUIDs spread inserts across the B-tree (some
  index fragmentation) in exchange for non-guessable, globally unique keys.
  `version` is maintained separately, so UUID randomness has no impact on
  concurrency control.

### 6.3 Timestamps and timezone strategy

- All timestamps use **`Instant`** mapped to PostgreSQL
  **`timestamp with time zone`** (`timestamptz`) and are stored in UTC. The JDBC
  connection runs with `hibernate.jdbc.time_zone: UTC`, so a value is never
  silently interpreted in the server's local timezone.
- `created_at` / `updated_at` are maintained by **Spring Data JPA auditing**
  (`@EnableJpaAuditing`, `AuditingEntityListener`) — see 6.4.
- `last_login_at` / `completed_at` are nullable UTC instants.
- **`completedAt` alignment on creation:** a task created directly as
  `COMPLETED` gets its `completedAt` aligned to `createdAt` in a `@PrePersist`
  callback (`Task`), because the database requires `completed_at >= created_at`
  while Spring Data auditing stamps `createdAt` microseconds after the service
  clock that set `completedAt`.
- `due_date` is a **calendar `DATE` (`LocalDate`) with no time and no timezone**.
  DateTime ambiguity is therefore impossible for due dates; converting to the
  user's local date is application logic (using `UserProfile.timezone`, a
  nullable IANA name such as `Asia/Kolkata`) in the task-management phase.

### 6.4 Auditing

- `BaseEntity` (mapped superclass) carries `createdAt` / `updatedAt` annotated
  with `@CreatedDate` / `@LastModifiedDate`; `JpaAuditingConfig` enables
  auditing. Timestamps are set consistently for every entity with no duplicated
  logic.
- Auditing is proven by `UserRepositoryIT.auditingPopulatesAndMaintainsTimestamps`
  (and coverage in the profile/task ITs).

### 6.5 Optimistic locking

- `BaseEntity` also carries `@Version long version`. Hibernate increments it on
  every update and includes it in the `WHERE` clause, so two concurrent writers
  are detected with `OptimisticLockingFailureException`.
- Proven by `UserRepositoryIT.versionStartsAtZeroAndIncrementsOnUpdate` and
  `optimisticLockingConflictIsDetected` (simulated stale update against the
  live database).

### 6.6 Normalization and integrity

- Usernames and emails are **trimmed and lower-cased** in a `@PrePersist`/
  `@PreUpdate` callback, so the unique constraints also guarantee
  case-insensitive uniqueness. The database independently enforces the
  normalized form with `CHECK (col = lower(col))`.
- Critical integrity is enforced **in the database**, not only in Java:
  NOT NULL columns, `UNIQUE (username)`, `UNIQUE (email)`,
  `UNIQUE (user_profiles.user_id)`, enum CHECKs
  (`account_status`, `task status` = TODO/IN_PROGRESS/COMPLETED/CANCELLED),
  `CHECK ((status='COMPLETED') = (completed_at IS NOT NULL))`, and
  `CHECK (updated_at >= created_at)`.
- `OVERDUE` is a **derived** state (due date passed, not completed, not
  cancelled) computed at runtime in a later phase; it is deliberately absent
  from the persisted status CHECK.

### 6.7 Delete behavior

- Both `user_profiles.user_id` and `tasks.user_id` foreign keys use
  **`ON DELETE CASCADE`**: removing a user removes their profile and tasks, so
  no orphaned rows can occur. Deleting a profile/task never affects the user.
  No user-deletion feature exists yet; this documents the behavior for when it
  does.

### 6.8 Indexes

| Index | Columns | Why |
| ----- | ------- | --- |
| `uk_users_username` (unique) | `username` | identity lookup + uniqueness (unique constraint backing index) |
| `uk_users_email` (unique) | `email` | identity lookup + uniqueness |
| `uk_user_profiles_user` (unique) | `user_id` | "one profile per user" + profile lookup |
| `idx_tasks_user_status` | `(user_id, status)` | "my tasks with status"; leftmost `user_id` prefix also serves the FK |
| `idx_tasks_user_due_date` | `(user_id, due_date)` | due-date ordering/filtering and overdue derivation; same prefix note |

The Phase 7 list/dashboard queries are covered by these existing indexes:
every filter and the default sort paths stay within the `(user_id, status)` or
`(user_id, due_date)` prefixes (and `(user_id, created_at)`-style ordering is
served by plain `user_id` scans at this scale), so **no new indexes or
migration** were added.

Global (unscoped) indexes on `status` / `due_date` are intentionally **not**
created — those queries are not part of the plan without a user scope.

### 6.9 Migration strategy

- Schema is 100% owned by versioned Flyway migrations in
  `backend/src/main/resources/db/migration` (`V1__create_users.sql`,
  `V2__create_user_profiles.sql`, `V3__create_tasks.sql`,
  `V4__create_refresh_tokens.sql`). `flyway_schema_history` is managed by Flyway
  only.
- Hibernate is in `validate` mode (`ddl-auto: validate`): it verifies every
  mapped entity against the migrated schema and never creates or alters tables.
  The schema is reproducible from migrations on a clean database; the
  Testcontainers integration tests prove this on every build.
- Migrations are immutable once merged; changes ship as new versions
  (`V5_...`).

## 6a. API communication (auth, profile, task & dashboard endpoints)

The Phase 4 auth endpoints, the Phase 5 profile endpoints, the Phase 6 task
endpoints and the Phase 7 listing/dashboard endpoints are implemented and
documented in [api-overview.md](api-overview.md):
`POST /api/v1/auth/register`, `POST /api/v1/auth/login`,
`POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`,
`GET/PUT/PATCH /api/v1/profile`, the task endpoints under `/api/v1/tasks`
(CRUD + `/status`, `/complete`, `/cancel`), the query-parameter task list, and
`GET /api/v1/dashboard`, plus the existing health endpoints. Fault handling,
envelopes and correlation are unchanged.

## 7. API communication

- REST over JSON, versioned under `/api/v1` (`ApiPaths.V1`).
- **Successes** use the `ApiResponse` envelope: `{ success, data, message }`.
- **Errors** use the `ApiError` envelope: `{ success, error: { code, message,
  details }, timestamp, path }`. Clients never receive stack traces,
  credentials or internal details.
- Error handling is centralized in `com.todoapp.exception.GlobalExceptionHandler`
  over the `ApiException` hierarchy (`ResourceNotFoundException`,
  `BadRequestException`, `ServiceUnavailableException`, ...).
- Documented with OpenAPI (springdoc) — UI served at `/swagger-ui.html`.
- Auth endpoints (Phase 4), the user-profile endpoints (Phase 5), the task
  endpoints (Phase 6) and the listing + dashboard endpoints (Phase 7) are live
  under `/api/v1/auth`, `/api/v1/profile`, `/api/v1/tasks` and
  `/api/v1/dashboard`; see [api-overview.md](api-overview.md) and
  [security.md](security.md).
- Backend remaining (Phase 8+): Flutter integration against the implemented
  APIs.

### Logging & correlation

- A `CorrelationIdFilter` propagates `X-Correlation-Id` (header → SLF4J MDC →
  response header), so every request can be traced across log lines.
- Unexpected failures are logged with full stack traces **internally only**;
  the client receives a safe, generic message.
- No passwords, tokens or sensitive user data are ever logged.

## 8. Environment configuration

- Configuration lives outside source code: all values are read from
  environment variables, with local-development defaults matching
  `infrastructure/.env.example`.
- Database settings (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`,
  `DB_PASSWORD`), CORS origins, the JWT secret/issuer/TTLs
  (`JWT_SECRET`, `JWT_ISSUER`, `JWT_ACCESS_TOKEN_EXPIRATION`,
  `JWT_REFRESH_TOKEN_EXPIRATION`) and the task-list page-size cap
  (`TASKS_MAX_PAGE_SIZE`, default `100`) are environment driven.
- See `docs/development-workflow.md` for the full setup.