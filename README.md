# Todo App

A personal TODO / task management application.

Web-first: the frontend is built with **Flutter Web**, the backend is a layered
**Java / Spring Boot** REST API backed by **PostgreSQL**. Schema management is
owned exclusively by **Flyway** migrations. Future Android and iOS clients will
reuse the current Flutter business/domain/data layers without a rewrite.

> **Status: Phase 20 — Final Enterprise Audit.**
> Phase 1 established the monorepo, builds, configuration and infrastructure;
> Phase 2 added response envelopes, the exception hierarchy, readiness checking
> and logging/correlation; Phase 3 added the PostgreSQL schema and JPA domain
> model (User, UserProfile, Task), Flyway migrations, repositories, auditing and
> optimistic locking. Phase 4 adds stateless JWT authentication: registration,
> login, rotated/persisted refresh tokens, logout, password hashing (BCrypt),
> the protected-route security chain and `/auth/me`. Phase 5 adds the caller-owned
> user profile API (`GET/PUT/PATCH /api/v1/profile`), IDOR-safe by construction,
> with IANA-timezone/URL validation, PATCH null-clearing semantics and optimistic
> locking. Phase 6 adds the authenticated task management REST API under
> `/api/v1/tasks`: CRUD, full/partial update, status lifecycle
> (`/status`, `/complete`, `/cancel`), server-controlled `completedAt`, optimistic
> locking and derived (non-persisted) `overdue`. Phase 7 adds the paginated,
> filterable, sortable, searchable task list (`GET /api/v1/tasks` with
> `page`/`size`/`sort`/`direction`/`status`/`dueDateFrom`/`dueDateTo`/`overdue`/
> `search`) and the caller-scoped dashboard statistics endpoint
> (`GET /api/v1/dashboard`). Phase 8 is a backend security + quality audit
> (findings + fixes shipped). Phase 9 lays the Flutter Web foundation: web-only
> project, `ApiClient`/envelope/error model, routing, design system, reusable
> widgets, accessibility and a 50-test green suite. Phases 10–16 deliver the
> design system, auth/register/profile UI, dashboard, task management, search/
> filters/sorting and enterprise UX polish. Phase 17 is automated testing and
> quality gates (291 backend + 329 frontend tests). Phase 18 adds Docker and
> Docker Compose: backend and frontend images, full stack orchestration with
> PostgreSQL 16, health checks, persistence, and container security. Phase 19
> adds the GitHub Actions CI pipeline: automated backend, frontend, and Docker
> validation on every push and pull request. Phase 20 is the final enterprise
> audit of the whole system (architecture, backend, database, frontend, Docker,
> CI/CD, secrets and documentation) with genuine defects fixed and a full
> regression run. See
> [docs/security.md](docs/security.md) and [docs/api-overview.md](docs/api-overview.md)
> for details, and the Phase reports below.

## Technology stack

| Layer             | Technology                                                        |
| ----------------- | ----------------------------------------------------------------- |
| Frontend          | Flutter (Dart), Flutter Web                                       |
| Backend           | Java 21, Spring Boot 3.5, Spring Web, Spring Data JPA, Hibernate  |
| Security          | Spring Security, JWT (jjwt 0.12), BCrypt                          |
| Database          | PostgreSQL                                                        |
| Migrations        | Flyway                                                            |
| API               | REST, OpenAPI / Swagger (springdoc)                               |
| Testing           | JUnit 5, Mockito, Spring Boot Test, Testcontainers                |
| Infrastructure    | Docker, Docker Compose                                            |
| CI/CD             | GitHub Actions                                                    |

## Repository structure

```
todo-app/
├── backend/          Spring Boot REST API
├── frontend/         Flutter Web application
├── docs/             Architecture, API and workflow documentation
├── infrastructure/   Docker Compose (PostgreSQL) and env templates
├── .github/          GitHub Actions CI workflow
├── .env.example      Root environment template
└── README.md
```

Internal package/config layout for each module is documented in
[docs/architecture.md](docs/architecture.md).

## Domain model (implemented)

```
User  (account/security data)          Task                UserProfile
├── id (UUID)                          ├── id (UUID)       ├── id (UUID)
├── username  (unique, normalized)     ├── user_id → User  ├── user_id → User  (unique)
├── email     (unique, normalized)     ├── title           ├── first/last name
├── passwordHash (never exposed)       ├── description     ├── displayName
├── accountStatus ACTIVE/DISABLED/LOCKED ├── status        ├── timezone
├── lastLoginAt                        ├── dueDate         └── profileImageUrl
├── version (optimistic lock)          ├── completedAt
└── createdAt / updatedAt              ├── version
                                       └── createdAt / updatedAt

RefreshToken  (login session, one per active refresh token)
├── id (UUID)          ├── user_id → User  (CASCADE)
├── tokenHash (SHA-256, unique)  ├── expiresAt  (hard ceiling)
└── revokedAt           └── version / createdAt / updatedAt
```

- `User` owns one `UserProfile` (1:1, enforced by a unique `user_id` foreign key).
- `Task` belongs to exactly one `User` (N:1, lazy, unidirectional).
- `OVERDUE` is **not** persisted; it is a derived state computed when a task's due
  date passes while it is not COMPLETED/CANCELLED. It is exposed per-task as
  `overdue` and aggregated in the dashboard's `overdueTasks` counter.
- The dashboard endpoint (`GET /api/v1/dashboard`) returns status + overdue counts
  over the caller's tasks only, from a single owner-scoped aggregate query.
- Refresh tokens store only a SHA-256 hash of the opaque token; they rotate on
  every refresh and are revoked by logout.
- The schema is created entirely by Flyway migrations (`V1`–`V4`); Hibernate runs
  in `validate` mode and never alters tables. See
  [docs/architecture.md](docs/architecture.md) for the full design.

## Prerequisites

- Java 21 (LTS) — e.g. Temurin `21` — with `JAVA_HOME` set
- Maven 3.9+ (or use the committed Maven wrapper `./mvnw`)
- Flutter SDK **stable** (verified against `3.47.x`)
- Docker + Docker Compose (for PostgreSQL and Testcontainers)

## Getting started

### 1. Configure environment

Copy the templates and adjust values if needed (the values match the host ports
published by the local Docker Compose setup — note `DB_PORT` is `5433`, the
host port Compose maps to PostgreSQL's container `5432`):

```bash
# backend + general
cp .env.example .env

# docker compose (infrastructure)
cp infrastructure/.env.example infrastructure/.env
```

No secrets are committed. See docs/development-workflow.md for details.

### 2. Start PostgreSQL

```bash
cd infrastructure
docker compose up -d
docker compose ps            # wait for "healthy"
```

The Postgres data directory persists in the `postgres_data` Docker volume.

### 3. Start the backend

```bash
cd backend

# with the committed Maven wrapper (recommended)
./mvnw spring-boot:run

# or with a system Maven
mvn spring-boot:run
```

The backend reads all database settings from the environment
(`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`) and falls back
to the local development defaults shown in `.env.example`.

Verify it is running:

- OpenAPI UI: <http://localhost:8080/swagger-ui.html>
- OpenAPI spec: <http://localhost:8080/v3/api-docs>
- Liveness: <http://localhost:8080/api/v1/health>
- Readiness (checks PostgreSQL): <http://localhost:8080/api/v1/health/readiness>

### 4. Start Flutter Web

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

`--dart-define=API_BASE_URL=...` is how the app learns the backend base URL.

### 5. Run checks and tests

Backend:

```bash
cd backend
./mvnw test                 # unit tests (no Docker required)
./mvnw verify              # unit + integration tests (Docker required; spins up PostgreSQL via Testcontainers)
```

Frontend:

```bash
cd frontend
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

### 6. Validate infrastructure

```bash
cd infrastructure
docker compose config          # validate the compose file
docker compose up -d           # start PostgreSQL + backend + frontend
docker compose ps              # confirm all healthy
```

### 7. Full stack (Docker Compose alternative)

For a one-command full local stack (backend, frontend, PostgreSQL):

```bash
cd infrastructure
docker compose up -d
docker compose ps            # all three containers should be "healthy"
```

The stack listens on:

| Service   | URL                           |
| --------- | ----------------------------- |
| Frontend  | <http://localhost:3000>        |
| Backend   | <http://localhost:8080>        |
| Swagger   | <http://localhost:8080/swagger-ui.html> |
| PostgreSQL | `localhost:5433`             |

## Development workflow

Branches (`main` is protected), commit conventions and migration handling are
described in [docs/development-workflow.md](docs/development-workflow.md).

## CI / CD

A GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and
pull request. Three parallel jobs validate the entire codebase:

| Job       | What it checks                                              |
| --------- | ----------------------------------------------------------- |
| Backend   | Java 21, Maven Wrapper, `./mvnw -B verify` (291 tests)     |
| Frontend  | Flutter 3.47.4, format, analyze, 329 tests, web build      |
| Docker    | Compose config, backend + frontend image builds              |

**Reproduce CI locally:**

```bash
# Backend
cd backend
chmod +x mvnw
./mvnw -B verify

# Frontend
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --concurrency 8
flutter build web --dart-define=API_BASE_URL=http://localhost:8080

# Docker
cd infrastructure
docker compose config --quiet
cd ../backend && docker build -t todo-app-backend:ci .
cd ../frontend && docker build -t todo-app-frontend:ci .
```

See [docs/phase-19-report.md](docs/phase-19-report.md) for the full CI/CD
report.

## Documentation

- [docs/architecture.md](docs/architecture.md) — system architecture and layering
- [docs/api-overview.md](docs/api-overview.md) — API conventions and contracts
- [docs/security.md](docs/security.md) — authentication/security design (Phases 4–7)
- [docs/development-workflow.md](docs/development-workflow.md) — how to work on this repo
- [docs/phase-5-report.md](docs/phase-5-report.md) — Phase 5 delivery report (user profile API)
- [docs/phase-6-report.md](docs/phase-6-report.md) — Phase 6 delivery report (task management backend)
- [docs/phase-7-report.md](docs/phase-7-report.md) — Phase 7 delivery report (dashboard + filters API)
- [docs/phase-8-report.md](docs/phase-8-report.md) — Phase 8 delivery report (security + quality audit)
- [docs/phase9-report.md](docs/phase9-report.md) — Phase 9 delivery report (Flutter Web foundation)
- [docs/phase-18-report.md](docs/phase-18-report.md) — Phase 18 delivery report (Docker / Compose / Environment)
- [docs/phase-19-report.md](docs/phase-19-report.md) — Phase 19 delivery report (CI/CD Pipeline)
- [docs/phase-20-report.md](docs/phase-20-report.md) — Phase 20 delivery report (Final Enterprise Audit)

## License

Private / internal project. All rights reserved.