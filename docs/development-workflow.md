# Development Workflow

## 1. Branching & workflow

- `main` is the long-lived, protected branch. It must always build and pass
  tests.
- Work happens on short-lived feature branches:
  `feature/<phase>-<short-name>` (e.g. `feature/2-auth`, `bugfix/...`).
- A change merges to `main` only through a reviewed pull request.
- Keep commits focused and use conventional commit messages:
  `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`.

## 2. Local setup (first time)

1. Prerequisites: Java 21 (`JAVA_HOME`), Maven 3.9+ (or use `./mvnw`),
   Flutter stable, Docker + Compose.
2. Copy environment templates:
   ```bash
   cp .env.example .env
   cp infrastructure/.env.example infrastructure/.env
   ```
   Adjust values only if your local setup differs. The defaults already match
   the Docker Compose database **as published on the host** (Compose maps
   PostgreSQL's container port 5432 to host 5433, so `DB_PORT` is `5433`), so
   most developers change nothing.

### Environment variables

| Variable             | Used by               | Default (local)       |
| -------------------- | --------------------- | --------------------- |
| `DB_HOST`            | Backend / Compose     | `localhost`           |
| `DB_PORT`            | Backend / Compose     | `5433` (host port Compose publishes; container is `5432`) |
| `DB_NAME`            | Backend / Compose     | `todo_app`            |
| `DB_USERNAME`        | Backend / Compose     | `todo_app`            |
| `DB_PASSWORD`        | Backend / Compose     | `todo_app`            |
| `SERVER_PORT`        | Backend               | `8080`                |
| `SPRING_PROFILES_ACTIVE` | Backend           | `dev`                 |
| `CORS_ALLOWED_ORIGINS`   | Backend           | localhost origins     |
| `JWT_SECRET`             | Backend (auth)    | local dev placeholder |
| `JWT_ISSUER`             | Backend (auth)    | `todo-app`            |
| `JWT_ACCESS_TOKEN_EXPIRATION` | Backend (auth) | `900` (15 min)        |
| `JWT_REFRESH_TOKEN_EXPIRATION` | Backend (auth) | `2592000` (30 days)   |
| `API_BASE_URL`       | Frontend (`--dart-define`) | `http://localhost:8080` |

Never commit real credentials. `JWT_SECRET` must be ≥ 32 characters and unique
in every non-local environment; a weak/missing secret prevents the backend from
starting (`JwtConfig` fails fast).

## 3. Starting the stack

```bash
# 1) Database
cd infrastructure && docker compose up -d

# 2) Backend (from repo root)
cd backend && ./mvnw spring-boot:run

# 3) Frontend (from repo root)
cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## 4. Database & migrations

- Schema changes **must** be delivered as versioned Flyway migrations in
  `backend/src/main/resources/db/migration/`. The current schema is
  `V1__create_users.sql`, `V2__create_user_profiles.sql`,
  `V3__create_tasks.sql`, `V4__create_refresh_tokens.sql`; new changes start at
  `V5`.
- Migrations are immutable once merged to `main`. Never edit an applied
  migration; create a new one.
- Hibernate `ddl-auto` is `validate` — Hibernate never creates/alters tables.
  The mapped entities are checked against the migrated schema on startup.
- Flyway runs automatically on backend startup. For local drop/recreate:
  ```bash
  docker compose down -v   # recreate the database from scratch
  docker compose up -d
  ```
- Every migration must work against a clean database — verified automatically
  by the Testcontainers integration tests on each build.

## 5. Backend build & tests

```bash
cd backend
./mvnw test        # unit tests only (no Docker required)
./mvnw verify      # unit + integration tests (Docker + Testcontainers)
./mvnw clean package -DskipTests   # build jar
```

- Unit tests (`*Test`) never require external services.
- Integration tests (`*IT`) use Testcontainers to provision a real PostgreSQL
  container and verify Spring context, JPA, Flyway wiring, the health/readiness
  endpoints, the standard API envelopes and the full auth chain (registration,
  login, refresh rotation, logout, account statuses) plus the profile API
  (ownership isolation, null-clearing PATCH, validation envelopes).
- The integration test also asserts production-safe settings:
  `spring.jpa.hibernate.ddl-auto=validate` and Flyway as the only schema tool.

### Auth & security conventions

- Passwords are BCrypt-hashed via `PasswordService`; never store or log
  plaintext. Only the SHA-256 hash of a refresh token is persisted.
- `JwtService` creates and parses access tokens; token state (expiry, issuer,
  signature) is validated on every protected request.
- Log in/register via `AuthService`, which owns the transactional lifecycle and
  the opaque `AUTHENTICATION_FAILED` fallback (no account enumeration).
- Auth errors use the stable codes from api-overview.md (e.g.
  `REFRESH_TOKEN_EXPIRED`, `ACCOUNT_DISABLED`); see [security.md](security.md).

### Profile conventions (Phase 5)

- Identity is always derived from the `AuthenticatedUser` principal — no
  profile/user id appears in the request path or body.
- `@NotBlankOrNull` (a custom constraint) allows `null` (clear) but rejects
  blank strings; `ValidTimezone` and `ValidHttpUrl` enforce domain-level
  format rules. Values are trimmed in `ProfileService` before persistence.
- PUT carries full bean-validation; PATCH validates programmatically via the
  same rules, using the `PatchField` sentinel to distinguish absent vs explicit
  `null` vs value.

### Coding conventions

- Controllers stay thin; business logic lives in services; transactions use
  `@Transactional` at the **service layer only** (read-only queries use
  `readOnly = true`). Never on controllers.
- API responses use the `ApiResponse`/`ApiError` envelopes; throw
  `com.todoapp.exception.ApiException` subclasses for controlled errors, never
  raw exceptions.
- Never log passwords, tokens or sensitive user data. Correlation IDs flow via
  `X-Correlation-Id` (see `CorrelationIdFilter`).
- Entities extend `com.todoapp.entity.BaseEntity` (UUID id, `@Version`,
  audited timestamps). Never expose `passwordHash` or any entity in a DTO.
- Domain rules that guard database integrity (e.g. `COMPLETED` ⇔
  `completedAt IS NOT NULL`, OVERDUE not persisted) are enforced by
  **database CHECK constraints** in the migration SQL, not only in Java.
- All writable varchar columns have an explicit `@Column(length = ...)` that
  matches the migration (`validate` checks lengths).
- Repositories expose ownership-scoped queries (`findByIdAndUserId`,
  `findByUserId`) — no global/unscoped access methods.

## 6. Frontend build & tests

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

Build artifacts are written to `frontend/build/web`.

## 7. Documentation

When a visible change affects consumers:

- Update `docs/api-overview.md` when API contracts change.
- Update `docs/architecture.md` when layers/components change.
- Update `docs/security.md` when security behavior changes.
- Keep the README runnable by anyone on the team.

## 8. Definition of done

- [ ] Code compiles and `./mvnw verify` passes (backend).
- [ ] `flutter analyze`, `flutter test`, `flutter build web` pass (frontend).
- [ ] Flyway migrations reviewed (schema is safe for existing databases).
- [ ] No secrets committed; `.env*` stays ignored.
- [ ] Docs updated if the change affects setup or contracts.

## 9. Phase reports

Phase delivery reports are stored in the repo for reference:

- `docs/phase-5-report.md` — Phase 5, user profile API.
- `docs/phase-6-report.md` — Phase 6, task management backend.
- `docs/phase-7-report.md` — Phase 7, dashboard + filters API.
- `docs/phase-8-report.md` — Phase 8, backend security + quality audit.
- `docs/phase9-report.md` — Phase 9, Flutter Web foundation.
- `docs/phase-10-report.md` … `docs/phase-19-report.md` — Phases 10–19 (design
  system, auth/profile/dashboard/tasks UI, search & filtering, enterprise UX,
  quality gates, Docker/Compose, CI/CD).
- `docs/phase-20-report.md` — Phase 20, final enterprise audit.