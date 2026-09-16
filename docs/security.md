# Security

This document describes how the Todo App backend authenticates requests and
protects account data (Phases 4–7).

## 1. Authentication model

The backend is **stateless**. Clients authenticate with a short-lived
**JWT access token** (15 minutes by default) in the `Authorization` header:

```
Authorization: Bearer <access-token>
```

Getting a token:

| Endpoint                   | What happens                                                            |
| -------------------------- | ----------------------------------------------------------------------- |
| `POST /api/v1/auth/register` | Creates an account (201). Does **not** hand out tokens.                 |
| `POST /api/v1/auth/login`    | Validates credentials, returns `{ accessToken, refreshToken, tokenType, expiresIn }`. |
| `POST /api/v1/auth/refresh`  | Rotates the refresh token, returns a new token pair.                    |
| `POST /api/v1/auth/logout`   | Revokes the presented refresh token (idempotent).                       |
| `GET  /api/v1/auth/me`       | Protected — returns the caller's identity.                              |

Public in the security chain (all other endpoints, including `GET /api/v1/auth/me`,
require a valid access token):

- `POST /api/v1/auth/register`, `POST /api/v1/auth/login`,
  `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`
- `/api/v1/health/**`, Swagger UI and OpenAPI JSON
- `OPTIONS` preflight (`/**`)

## 2. Passwords

- Passwords are hashed with **BCrypt** (`BCryptPasswordEncoder`, strength 10).
- Only the hash is ever stored (`users.password_hash`, up to 255 chars). The
  plaintext is never persisted or logged and never appears in any DTO.
- API requests carry the password only inside the login/register body; the
  service immediately hashes or verifies and discards it.
- Policy (enforced by bean validation on `RegisterRequest`): 10–100 characters,
  must contain at least one letter and one digit.

## 3. Access tokens (JWT)

- **HS256** signature (HMAC-SHA-256). The key is derived from
  `app.security.jwt.secret` (environment: `JWT_SECRET`) and must be at least 32
  characters; `JwtConfig` fails fast at startup if it is missing or too short.
- Claims contain **identity only**: `sub` (user UUID), `iss` (`JWT_ISSUER`,
  default `todo-app`), `iat`, `exp`, and `username`. No sensitive data is ever
  placed in a token.
- Validation on every protected request: signature, issuer, and expiry are all
  checked (`JwtService.parseAccessToken`). Failures produce an `ApiError` with
  code `TOKEN_EXPIRED` or `TOKEN_INVALID`.
- The token never stores the password hash or any profile/email data.

### Secret management

- `JWT_SECRET` must be set to a strong, unique, randomly generated value in
  every environment except local development.
- The default in `application.yml` is a **disposable local-only placeholder**
  and is never used by the test profile.
- **Known limitation:** `JwtConfig` fails fast for a missing or too-short
  secret, but it does **not** detect the well-known placeholder value at
  startup — a non-local deployment that ships the placeholder (e.g. an
  unedited `cp .env.example .env`) still boots with a public, known key. This
  is deliberate to keep the zero-config local Docker/dev flow working; the
  placeholder must be rejected by operational guardrails (config validation,
  secrets manager) today, and a profile-guarded startup check is the
  recommended hardening (Phase 20 finding B1).
- Secrets are never committed. Rotate the secret by changing `JWT_SECRET` (this
  invalidates all outstanding access tokens — acceptable for this app).

## 4. Refresh tokens (persisted sessions)

- Each refresh token is an **opaque 256-bit random value** (48 bytes, base64url
  encoded). It is returned **once** to the client.
- Only the **SHA-256 hex digest** is stored in the database
  (`refresh_tokens.token_hash`, unique). A database leak therefore does not
  expose usable tokens.
- **Single-use / rotation:** every successful `/auth/refresh` revokes the
  presented token and issues a replacement. Replaying an old token yields
  `REFRESH_TOKEN_INVALID`.
- **Hard lifetime ceiling:** `expires_at` is fixed when the session is created
  (default 30 days via `JWT_REFRESH_TOKEN_EXPIRATION`). Rotation preserves the
  original ceiling — a session can never outlive it by continuously
  refreshing.
- **Logout:** `/auth/logout` sets `revoked_at`. A revoked or expired token can
  never be used again. Logout is idempotent.
- **Cascade:** deleting a user (`users` row) cascades to all of its sessions
  (`fk_refresh_tokens_user ... ON DELETE CASCADE`).

### Why not JWT refresh tokens?

Storing an opaque token (instead of a second JWT) gives real revocation: we can
enforce single-use, a hard expiry ceiling, and logout. A stateless refresh JWT
could not be revoked without a blacklist, which is strictly worse.

## 5. Account status

`users.account_status` is one of:

| Status     | Login          | Token validation (filter) | Refresh         |
| ---------- | -------------- | ------------------------- | --------------- |
| `ACTIVE`   | allowed        | allowed                   | allowed         |
| `DISABLED` | `403 ACCOUNT_DISABLED`  | rejected (`TOKEN_INVALID`) | `403 ACCOUNT_DISABLED` |
| `LOCKED`   | `403 ACCOUNT_LOCKED`    | rejected (`TOKEN_INVALID`) | `403 ACCOUNT_LOCKED`   |

- `last_login_at` is updated **only** on a successful password login — never on
  refresh or token validation alone.
- Login failures never reveal whether the username/email exists (opaque
  `AUTHENTICATION_FAILED` for unknown account *and* wrong password), preventing
  account enumeration.

## 6. Request pipeline

Public endpoints run straight through. Protected endpoints pass through:

1. `JwtAuthenticationFilter` (`security/filter/`) — parses the Bearer token and,
   on success, loads the user and requires `ACTIVE` before populating the
   `SecurityContext` with an `AuthenticatedUser` principal.
2. `SecurityConfig` — stateless, CSRF disabled, CORS via `CorsConfig`, session
   policies; static permit lists for auth/health/OpenAPI.
3. Filter-stage errors are written by `RestAuthenticationEntryPoint` (401) and
   `RestAccessDeniedHandler` (403) using the same `ApiError` envelope as the
   `GlobalExceptionHandler` (which serves controller-stage errors).

The JWT filter is instantiated in `SecurityConfig` (not annotated as a Spring
component) so Spring Boot does not register a duplicate instance on the default
chain.

## 7. CORS

- Configured via `app.cors.allowed-origins` (environment:
  `CORS_ALLOWED_ORIGINS`), e.g. the Flutter web dev server.
- Allowed methods: GET/POST/PUT/PATCH/DELETE/OPTIONS; allowed headers: all;
  credentials allowed (needed for the `Authorization` header); the
  `X-Correlation-Id` response header is exposed to browsers.
- No `*` origin in production; origins are always explicit.

## 8. Testing

- **Unit:** `JwtServiceTest` (signing/expiry/issuer/tampering), `PasswordServiceTest`
  (BCrypt lifecycle), `RefreshTokenServiceTest` (issue/rotate/revoke/expiry,
  hash-only storage), `AuthServiceTest` (orchestration and error mapping),
  `ProfileServiceTest` (upsert/replace/patch semantics, validation, optimistic
  lock error mapping).
- **Integration:** `AuthIntegrationIT` and `ProfileApiIT` exercise the full
  security chain against a real PostgreSQL/Testcontainers database:
  register/login/refresh rotation and replay rejection, logout revocation,
  disabled/locked accounts, anonymous rejection, forged expired tokens, and the
  profile resource (ownership isolation, disable/lock blocking, validation
  envelopes, PATCH partial/null semantics, versioning/auditing).
  `RefreshTokenRepositoryIT` covers the `refresh_tokens` table constraints and
  cascades. `DatabaseSchemaIT` asserts the V4 migration contents.

## 8b. Profile authorization and ownership (Phase 5)

The profile endpoint is deliberately **IDOR-safe by construction**:

- The resource is **caller-owned and single**: `GET/PUT/PATCH /api/v1/profile`
  operate on the profile of the authenticated principal. There is no
  `{profileId}` path segment and no query parameter that selects a user.
- **Identity is never taken from the body.** A client that sneaks a `userId`
  field into a request has it silently ignored (unknown JSON properties are
  dropped by the mapping layer); the owner is always the `AuthenticatedUser`
  loaded by `JwtAuthenticationFilter`. Tests verify a cross-user write lands on
  the caller, not the spoofed user.
- Requests are authorized twice: the JWT filter requires an `ACTIVE` account on
  every protected request (disabled/locked → `TOKEN_INVALID`), and the profile
  service re-dispatches purely on the authenticated principal.
- Responses are DTO-only (`ProfileResponse`); the `User` entity (with
  `passwordHash`) is never serialized.

## 8c. Task authorization, ownership and lifecycle (Phase 6)

The task API applies the same IDOR-safe principles to a **multi-instance,
caller-owned** resource:

- **Ownership is always derived from the principal.** The owner of every task
  comes from the `AuthenticatedUser` in the JWT filter — there are no
  user-scoped list endpoints and no request field selects an owner. A client
  that sneaks a `userId`/`completedAt` into the body has them silently ignored.
- **Lookup is scoped in the database.** Every read/write resolves the task with
  `TaskRepository.findByTaskIdAndUserId(taskId, userId)` (ID + owner), so a
  missing id and a foreign id produce the *same* `404 TASK_NOT_FOUND` — the API
  never reveals whether another user's task exists (no enumerable task id space
  leak). Integration tests assert cross-user reads/writes return `404`, never
  the other user's data.
- **Defense in depth:** the security chain (`anyRequest().authenticated()` +
  `ACTIVE` account check) protects all `/api/v1/tasks/**` routes, and the
  service re-checks ownership on every operation. `DELETE`/mutations never
  cascade across users.
- **Server-controlled integrity fields:** `completedAt` is generated from the
  injected `Clock` only when a task becomes `COMPLETED`; the `version`/`updatedAt`
  are maintained by JPA + `@Version` optimistic locking (409 on conflict). No
  request can set them.
- **State machine at the service layer:** transitions outside the allowed map
  raise `InvalidTaskTransitionException` → `409 INVALID_TRANSITION`; `OVERDUE`
  is never accepted as a status. The database additionally enforces the four
  status values and the `completed ⇔ completed_at` invariant via `CHECK`
  constraints.

## 8d. Task listing and dashboard authorization (Phase 7)

The list and dashboard endpoints are **read-only extensions of §8c** and keep
every IDOR-safe property:

- **Scoping is in the query, not the parameters.** `GET /api/v1/tasks` builds
  its `WHERE` with `TaskSpecifications.forUserAndFilters(...)`, whose **first
  conjunct is always `user_id = principal`**; `overdue`, `status`, `dueDate`,
  `sort` and `search` can only narrow that result set. No query parameter can
  reference another user, and cross-user filter/search attempts are covered by
  integration tests.
- **Dashboard counts are per-caller aggregates.** `GET /api/v1/dashboard`
  executes a single JPQL aggregate query filtered by the principal's id; the
  response exposes only six counts (no user ids, no task rows).
- **Params are validated, never guessed.** Unsupported `sort`, `status`,
  `direction`, `overdue` and malformed dates/pagination raise the standard
  `400 VALIDATION_ERROR` with field-level details — nothing is silently ignored
  or clamped, so the contract cannot be probed into a different query shape.
- **Routes are protected by the chain.** `/api/v1/dashboard` is an explicitly
  authenticated route in `SecurityConfig` (`ApiPaths.DASHBOARD`), alongside the
  existing `anyRequest().authenticated()` catch-all for `/api/v1/tasks/**`.

## 9. Non-goals (Phase 7)

- No shared/public tasks, no task permissions — tasks are strictly private to
  their owner.
- No admin task management, import/export, notifications, or "assigned to"
  collaboration.
- No dashboard beyond the six caller-scoped counters (no charts/aggregate
  history endpoint).
- Phase 7 is backend-only; no Flutter UI changes.

## 9a. Non-goals (Phase 6)

- No profile-image upload/storage — only an external `http(s)` URL reference.
- No admin or user-management APIs for profiles.
- No notifications when a profile is cleared.

## 10. Non-goals (Phase 4)

- No email verification, password reset, "remember me", or multi-device session
  listing. Password-change and admin/user-management APIs arrive in later phases.
- Rate limiting / brute-force lockout is a documented future enhancement; the
  `LOCKED` status is supported by the model today.

## 11. Operation checklist (release)

- [ ] `JWT_SECRET` is a strong unique value in every environment (≥ 32 chars).
- [ ] `CORS_ALLOWED_ORIGINS` lists only real frontend origins.
- [ ] Database backups include `refresh_tokens` (needed to keep sessions valid).
- [ ] No password hash, raw refresh token, or secret is committed or logged.