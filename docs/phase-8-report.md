# Phase 8 Report — Backend Security + Quality Audit

## 1. Overall Assessment
The backend is **in good security and quality shape**. The audit traced every request flow end-to-end (register → login → refresh/logout → profile/tasks/dashboard) and reviewed configuration, controllers, DTOs, validation, services, repositories, entities, Flyway migrations, JPA query logic, exception handling, logging, OpenAPI, tests, dependencies and infrastructure. All security-critical behaviors are enforced at multiple layers (entity normalization, service ownership checks, JPA specs, `CHECK`/`UNIQUE`/`FK CASCADE` DB constraints, JWT filter status checks) and — crucially — are **covered by tests**. One genuine defect was found (see §3/§4); it was fixed with tests. Verification is fully green.

## 2. Areas Audited
- Config: `application.yml`, `application-test.yml`, `.env.example`, `docker-compose.yml`, `pom.xml`, `JwtConfig`, `CorsConfig`, `JpaAuditingConfig`, `OpenApiConfig`, `CorrelationIdFilter`
- Security: `SecurityConfig`, `JwtAuthenticationFilter`, `RestAuthenticationEntryPoint`, `RestAccessDeniedHandler`, `TokenAuthenticationException`, `JwtService`, `RefreshTokenService`, `AuthService`
- API: `AuthController`, `ProfileController`, `TaskController`, `DashboardController`, `HealthController` + all DTOs (auth/task/profile/dashboard, PATCH deserializers)
- Domain/data: `User`, `UserProfile`, `Task`, `RefreshToken`, `BaseEntity`, all 4 repositories, `TaskSpecifications`, Flyway V1–V4
- Transactions & locking on all services; error contract; logging & correlation IDs; OpenAPI accuracy; test coverage matrix (unit + Testcontainers IT).

## 3. Issues Discovered
**Genuine (fixed):**
- `HttpRequestMethodNotSupportedException` (405), `HttpMediaTypeNotSupportedException` (415) and `HttpMediaTypeNotAcceptableException` (406) were swallowed by the `Exception.class` catch-all in `GlobalExceptionHandler`, so wrong-method / unsupported-media-type requests returned **500 INTERNAL_ERROR instead of the correct HTTP status**, and — critically — a non-conforming error body (Spring's default JSON) instead of the documented `ApiError` envelope. This violated the error contract and masked the real status.

**Observations / accepted tradeoffs (not changed — no genuine defect):**
- `/auth/refresh` and `/auth/logout` are intentionally public (credentials are in the body); an attacker who steals a refresh token can already refresh, so logout-offline is not a real exposure.
- `CorsConfig` uses `allowedHeaders("*")` with `allowCredentials(true)`: acceptable because origins are strictly allowlisted and `*` headers only echoes requested headers; client-side scripting is confined to the allowed origins.
- Missing 405/415/406 handling was the only contract gap; everything else routes through the standard envelope.

## 4. Fixes Made
Added three `@ExceptionHandler` methods to `GlobalExceptionHandler` so framework-level errors return the standard envelope with the correct HTTP status:
- 405 `METHOD_NOT_ALLOWED`
- 415 `UNSUPPORTED_MEDIA_TYPE`
- 406 `NOT_ACCEPTABLE`

## 5. Files Changed
- `backend/src/main/java/com/todoapp/exception/GlobalExceptionHandler.java` — 3 new handlers (+ imports)
- `backend/src/test/java/com/todoapp/exception/GlobalExceptionHandlerTest.java` — +3 unit tests
- `backend/src/test/java/com/todoapp/TaskApiIT.java` — +2 end-to-end ITs (405 via `GET /api/v1/tasks/{id}/complete`, 415 via `text/plain` POST)

## 6. Security Improvements Confirmed (audited, already present)
- Opaque 401 for both unknown-user and wrong-password login (no account enumeration); account-state codes (`ACCOUNT_DISABLED`/`ACCOUNT_LOCKED`) are only reachable after a correct password.
- Refresh tokens: 384-bit `SecureRandom`, stored only as SHA-256 hashes, hard expiry ceiling preserved on rotation (no sliding window), single-use with revocation → replay yields `REFRESH_TOKEN_INVALID`; rotation rolls back if the account is disabled/locked.
- Access tokens: HS256 with ≥32-char-enforced secret (fail-fast at startup), issuer-required, expiry-aware; `completed_at`/ownership never client-controlled; disabled/locked users are rejected on **every** request at the filter (springs from `findById` status check).
- IDOR impossible by construction: all queries keyed by `principal.userId()`, foreign task = 404. Covered by ITs for profile, task (incl. spoofed `userId` in body) and dashboard isolation.
- DB hardening: `CHECK` constraints (task completed⇔completed_at, timestamps, status enum, lowercase normalization), unique constraints, `ON DELETE CASCADE`, optimistic locking (`@Version`).

## 7. Database Findings
- Migrations V1–V4 validated by Flyway; `ddl-auto: validate` + `DatabaseSchemaIT` prove Hibernate matches the applied schema (both fresh-applied and existing).
- Constraints/invariants enforced and tested at the DB layer: completed⇔completed_at, completed_at≥created_at, status CHECK, lower() normalization, one-profile-per-user, cascade deletes for user→tasks/profile/refresh_tokens.
- No migration changes needed; no new indexes needed (see §8).

## 8. Query Performance Findings
- Dashboard uses a single user-scoped aggregate query (`countDashboard`) — no entity materialization, one round trip.
- List query is user-scoped via spec + allowlisted sort with deterministic `id` tie-breaker; page size hard-capped (`app.tasks.max-page-size`, default 100).
- Existing `(user_id, status)` and `(user_id, due_date)` indexes serve all status/due-date/overdue filters and the FK lookups; username/email uniqueness backs login lookups; `find_by_token_hash` is an indexed unique read.
- Search (`lower(title|description) LIKE %…%` with `%`/`_`/`\` escaping) is a documented leading-wildcard scan — acceptable at current scale; an expression index would be unjustified now (per Phase 7 conclusion, no new index).
- No N+1: response mapping touches only loaded scalar fields.

## 9. Validation Findings
- Bean validation on all DTOs (`@NotBlank/@Size/@Email/@Pattern`, custom `@NotBlankOrNull/@ValidTimezone/@ValidHttpUrl`); service-level validation for PATCH and list-query params with field-level `VALIDATION_ERROR` details; programmatic checks mirror DTO rules.
- Server clock is the sole source of `completedAt`; client-submitted `completedAt`/`userId`/unknown fields are ignored (verified by ITs).
- No DTO allows a blank string to persist; lengths are capped at DB/domain limits on both branches.

## 10. Logging Findings
- Correlation ID (`X-Correlation-Id`) propagated via MDC into the console pattern and echoed in responses; CORS exposes the header to the web client.
- Every request is access-logged with method/URI/status/duration; auth/authorization failures and validation/conflicts are `WARN`; unexpected exceptions are `ERROR` with full stack.
- **No secrets or internal details are ever logged** (verified by code and `GlobalExceptionHandlerTest` message-scrubbing test).

## 11. Dependency Findings
- Spring Boot 3.5.16, Java 21, jjwt 0.12.6, springdoc 2.8.17 (current patch releases). Flyway core + postgres module included. BCrypt via Spring Security.
- Runtime scopes correct (postgres/jjwt-impl/jjwt-jackson); mockito-core excluded via Boot parent Testcontainers setup (Testcontainers-only scanning); no unused or vulnerable dependency flagged; Maven wrapper pinned.

## 12. Error-Handling Findings
- All client responses use the `ApiError` envelope `{success, error{code,message,details}, timestamp, path}`; 401/403 at the filter stage are produced by `RestAuthenticationEntryPoint`/`RestAccessDeniedHandler`; `TokenAuthenticationException` codes (`TOKEN_EXPIRED`/`TOKEN_INVALID`) reach clients without leaking internals.
- After the §4 fix, the envelope now applies to **all** error classes including framework-level 405/415/406 (previously the only gap).

## 13. Test Coverage Improvements
Audit verified the Phase 8 required security matrix is tested end-to-end against real PostgreSQL 16 + full security chain:
- Authentication (register/login/me) ✓; invalid & expired JWT ✓; refresh rotation + replay → invalid ✓; logout revocation ✓; disabled & locked accounts at filter (pre-issued token) and at refresh ✓
- Profile/task/dashboard IDOR ✓; spoofed `userId`/`completedAt` ignored ✓; invalid transitions 409 ✓; optimistic-locking propagation and DB conflict ✓
- Overdue derivation (flag, filter, dashboard consistency) ✓; pagination/sort/filter/search/validation (incl. LIKE escaping) ✓; schema/index/constraint/Hibernate-validate ITs ✓
- **New this phase:** 405 and 415 envelope contracts now covered by unit tests + ITs (+5 tests total; see §14). No previously-uncovered security claim found.

## 14. Exact Verification Results
Environment: `JAVA_HOME=C:\Users\Sumit\.jdks\ms-21.0.12.1` (Java 21.0.12.1), Maven wrapper.
Command: `.\mvnw.cmd -B clean verify` (in `backend\`)
- Unit tests: **133 run, 0 failures** (incl. +3 `GlobalExceptionHandlerTest`)
- Integration tests: **135 run, 0 failures** (incl. +2 `TaskApiIT`)
- **Total: 268 tests, 0 failures, 0 errors, 0 skipped — BUILD SUCCESS** (01:40 min)

## 15. Docker Verification
Command: `docker compose config --quiet` (in `infrastructure\`, Docker 29.7.2)
Result: **COMPOSE_OK** — Postgres 16-alpine service, env overrides, healthcheck and volume all valid.

## 16. Security Checklist
| Item | Status |
|---|---|
| BCrypt password hashing, no plaintext storage | PASS |
| JWT secret ≥32 chars, startup fail-fast | PASS |
| JWT signature/issuer/expiry validation | PASS |
| Refresh tokens hashed-at-rest, single-use, ceiling preserved, revocable | PASS |
| Disabled/locked account enforcement on every request | PASS |
| IDOR protection (profile/tasks/dashboard) | PASS |
| `completedAt`/ownership not client-controllable | PASS |
| Lifecycle transition rules (terminal states, idempotent no-ops) | PASS |
| Optimistic locking (@Version) | PASS |
| User-scoped queries / no cross-user leak | PASS |
| CORS origin allowlist (no wildcard origins) | PASS |
| Error contract: unified ApiError envelope (incl. 405/415/406) | PASS |
| No secret/internal leakage in errors or logs | PASS |
| `ddl-auto: validate`, Flyway-managed schema, DB CHECK constraints | PASS |
| Stateless sessions, CSRF-disabled + JWT bearer only | PASS |
| Pagination/sort/filter/search bounded and validated | PASS |
| Correlation IDs on all logs + responses | PASS |

## 17. Remaining Risks / Recommendations (out of Phase 8 scope, no code changes)
- **No rate limiting / brute-force protection** on login/register/refresh — recommend an ingress/LB or future rate-limiter module (a new dependency/feature).
- **No refresh-token "family" revocation** on reuse of an already-rotated token — currently returns invalid; revoking all of a user's sessions on suspected theft is a hardening enhancement.
- **Default dev secrets** (`JWT_SECRET`, `DB_PASSWORD`) are local-only placeholders; `.env.example` flags "CHANGE ME" — must be overridden in every real environment (HTTPS/TLS assumed at the edge).
- `CORS allowedHeaders("*")` — can be tightened to an explicit header list if desired (not a defect given the origin allowlist).
- `/swagger-ui` and `/v3/api-docs` are public by design; disable via `springdoc.*.enabled=false` in prod if undesired, or protect behind the ingress.

## 18. Confirmations & Stop
- **Phase 9 was NOT implemented**: no notifications, email, sharing, admin, CI/CD, monitoring, or any product feature was added. Scope was strictly the Phase 8 audit + the single defect fix, each justified.
- **No commit was created** — the working tree was left uncommitted, as required.
- Phase 8 is complete. **Stopping.**