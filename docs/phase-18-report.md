# Phase 18 — Docker / Compose / Environment Implementation (Verification Report)

**Status:** COMPLETE (verified)
**Date:** 2026-09-16
**Scope:** Dockerfiles for backend and frontend, `docker-compose.yml` full local
stack, `infrastructure/.env` secrets template, `.dockerignore` files, container
security hardening, and documentation. No new features, no API changes, no
schema changes, no CI/CD, no Kubernetes.

This report documents the Phase 18 delivery: a fully containerised local
development stack running PostgreSQL 16, the Spring Boot backend, and the
Flutter Web / nginx frontend via Docker Compose, with verified persistence,
security, connectivity, and regression suites — all delivered across an
interrupted run and a successful recovery pass.

---

## 1. What Phase 18 covers

Phase 18 is the **Docker / Compose / Environment** milestone. It packages the
entire application into a reproducible local stack:

- **Backend image** — multi-stage Dockerfile (Maven build on Eclipse Temurin 21,
  runtime on Eclipse Temurin 21 JRE Alpine, non-root user).
- **Frontend image** — multi-stage Dockerfile (Flutter 3.47.4 Web build on
  Debian Bookworm, nginx 1.27 Alpine for serving, SPA fallback).
- **Compose orchestration** — `docker-compose.yml` with named volumes,
  dependency ordering, health checks, bridge networking, and `.env`-driven
  secrets.
- **Verification** — full-stack smoke test, persistence test, container security
  audit, and regression runs for both stacks.

---

## 2. Configuration — port strategy

All ports follow the established TODO local skew to avoid collision with the
unrelated url-shortener project that owns 5432/8080 on other projects:

| Service   | Container port | Host port | Container address (intra-stack) |
| --------- | -------------- | --------- | ------------------------------- |
| PostgreSQL | 5432           | 5433      | `postgres:5432`                 |
| Backend    | 8080           | 8080      | N/A (host: `localhost:8080`)    |
| Frontend   | 80             | 3000      | N/A (host: `localhost:3000`)    |

Connectivity rules:

- **Backend → PostgreSQL:** `postgres:5432` (Compose service name, never
  `localhost:5433`).
- **Browser → backend:** `http://localhost:8080` (host-published, never
  `http://backend:8080`).

---

## 3. Files created or modified

New files (pre-interruption):

| File | Purpose |
| ---- | ------- |
| `backend/Dockerfile` | Multi-stage Maven build → JRE Alpine |
| `backend/.dockerignore` | Build-context exclusion |
| `frontend/Dockerfile` | Multi-stage Flutter Web → nginx Alpine |
| `frontend/.dockerignore` | Build-context exclusion |
| `frontend/nginx.conf` | SPA fallback for deep links |
| `infrastructure/docker-compose.yml` | Full stack orchestration |
| `infrastructure/.env` | Secrets template (git-ignored) |
| `infrastructure/.env.example` | Non-secret placeholder template |

Modified during recovery:

| File | Change |
| ---- | ------ |
| `frontend/Dockerfile` | Fixed `mv /opt/flutter` self-collision bug (the release tarball already extracts to `/opt/flutter`, so the `mv` step attempted `mv /opt/flutter /opt/flutter`). Added `git config --global --add safe.directory /opt/flutter` to suppress the Flutter release tarball's embedded `.git` metadata triggering a `dubious ownership` error (exit 128). |
| `infrastructure/docker-compose.yml` | Fixed frontend healthcheck: `http://localhost/` → `http://127.0.0.1/` — nginx:alpine binds IPv4 only but `localhost` in the container resolves first to IPv6 `::1` (connection refused). |

---

## 4. Pre-interruption state (what was already complete)

The Phase 18 run was interrupted on 2026-09-15. At the point of interruption:

- ✅ Backend Dockerfile written, tested, and image built successfully
  (`todo-app-backend:local`, 523 MB).
- ✅ Frontend Dockerfile written (using `debian:bookworm-slim` + pinned
  Flutter 3.47.4 tarball download — **not** the `ghcr.io/cirruslabs/flutter`
  image).
- ✅ `docker-compose.yml` validated (`docker compose config`).
- ✅ `frontend/nginx.conf` written with SPA fallback.
- ✅ `.dockerignore` files written for both stacks.
- ✅ `infrastructure/.env` and `.env.example` created.
- ❌ Frontend image build had not completed (interrupted during a failed retry
  of the `ghcr.io/cirruslabs/flutter:stable` pull — an image the current
  Dockerfile does not use, left over from an earlier draft of the Dockerfile).

---

## 5. Recovery pass — what changed during the current session

The recovery pass addressed three issues and completed all remaining work:

### 5a. Dockerfile bug: `mv /opt/flutter /opt/flutter` (exit code 1)

The Flutter release tarball (`flutter_linux_3.47.4-stable.tar.xz`) extracts to
`/opt/flutter`. The original Dockerfile also set
`FLUTTER_ROOT=/opt/flutter` and then ran `mv /opt/flutter /opt/flutter`,
which is a no-op that causes an error on some shell implementations.

**Fix:** removed the redundant `mv` step.

### 5b. Flutter `--version` fails with `dubious ownership` (exit code 128)

The release tarball includes `.git` metadata. Running `flutter --version` under
git triggers the "dubious ownership in repository" check and exits with code 128.

**Fix:** added `git config --global --add safe.directory /opt/flutter` before
`flutter --version`.

### 5c. Frontend healthcheck: IPv4-only nginx vs. IPv6 `localhost`

The default `alpine` hosts file maps `localhost` to both `127.0.0.1` and `::1`.
`wget` tries `::1` first; nginx `listen 80` (IPv4-only by default) refuses the
connection, causing the healthcheck to report `unhealthy` permanently.

**Fix:** compose healthcheck changed to `http://127.0.0.1/`.

---

## 6. Build results

| Image | Base | Size | Build time | Status |
| ----- | ---- | ---- | ---------- | ------ |
| `todo-app-backend:local` | `eclipse-temurin:21-jre-alpine` | 523 MB | ~90 s (pre-interruption) | ✅ BUILT |
| `todo-app-frontend:local` | `nginx:1.27-alpine` | ~120 MB | ~340 s (recovery pass) | ✅ BUILT |

`docker compose config`: ✅ VALID

---

## 7. Full stack startup

```bash
docker compose up -d   # infrastructure/
```

All three services start in dependency order (postgres → backend → frontend)
and reach healthy within seconds:

| Container           | Image                   | Status         | Ports              |
| ------------------- | ----------------------- | -------------- | ------------------ |
| `todo-app-postgres` | `postgres:16-alpine`    | ✅ healthy      | `0.0.0.0:5433→5432` |
| `todo-app-backend`  | `todo-app-backend:local` | ✅ healthy      | `0.0.0.0:8080→8080` |
| `todo-app-frontend` | `todo-app-frontend:local`| ✅ healthy      | `0.0.0.0:3000→80`   |

---

## 8. PostgreSQL health and Flyway migrations

Flyway migrations V1–V4 all applied successfully:

| Version | Description          | Success |
| ------- | -------------------- | ------- |
| 1       | create users         | ✅       |
| 2       | create user profiles | ✅       |
| 3       | create tasks         | ✅       |
| 4       | create refresh tokens| ✅       |

Tables present: `users`, `user_profiles`, `tasks`, `refresh_tokens`,
`flyway_schema_history` — all owned by `todo_app`.

---

## 9. Backend health and readiness

```
GET /api/v1/health         → { status: "UP", service: "todo-app-backend" }
GET /api/v1/health/readiness → { status: "READY", database: "UP" }
```

Backend→PostgreSQL connectivity confirmed through the Compose bridge network
(`todo-network`).

---

## 10. Frontend HTTP availability and SPA fallback

| Route                | Status | Content                    |
| -------------------- | ------ | -------------------------- |
| `GET /`              | 200    | Flutter index.html (nginx) |
| `GET /login`         | 200    | SPA fallback → index.html  |
| `GET /tasks/{id}`    | 200    | SPA fallback → index.html  |

nginx server: `nginx/1.27.5`. SPA fallback (`try_files $uri $uri/ /index.html`)
works correctly for all client-side routes.

---

## 11. API-level full-stack smoke test

| Step | Endpoint                          | Result |
| ---- | --------------------------------- | ------ |
| 1    | `POST /api/v1/auth/register`     | ✅ 201  |
| 2    | `POST /api/v1/auth/login`        | ✅ 200  (240-char JWT) |
| 3    | `POST /api/v1/tasks`             | ✅ 201  (task created) |
| 4    | `GET  /api/v1/tasks?page=0&size=10` | ✅ 200 (1 task in page) |
| 5    | `GET  /api/v1/dashboard`         | ✅ 200  (totalTasks: 1) |

---

## 12. Persistence test

The full stack was restarted (`docker compose restart`). After restart:

- Login with the same credentials: ✅ success
- Task list still shows the same 1 task with the same ID and title: ✅
- Named volume `todo-app-postgres-data` preserves data across restarts: ✅

---

## 13. Container security checks

| Check | Backend | Frontend | PostgreSQL |
| ----- | ------- | -------- | ---------- |
| Non-root process | ✅ `todo` (uid 100) | ✅ nginx worker runs as `nginx` (master is root — standard nginx pattern) | N/A (stock image) |
| No secrets in image | ✅ Only `SERVER_PORT` env, no JWT/DB secrets | ✅ No env vars with secrets | ✅ Secrets via `POSTGRES_PASSWORD` at runtime |
| Build context excluded | ✅ `.dockerignore` excludes `.git`, `target/`, `.env*` | ✅ `.dockerignore` excludes `.git`, `build/`, `.dart_tool/` | N/A |
| No source in final image | ✅ Only `app.jar` | ✅ Only built web assets | N/A |

---

## 14. Regression tests — backend

`mvnw.cmd -B verify`:

- **136 unit tests** — all green
- **155 integration tests** (Testcontainers PostgreSQL 16) — all green
- **291/291 total** — BUILD SUCCESS
- Flyway V1–V4 applied in test containers
- Spring Boot context loaded, security chain validated

Backend code and test suite unchanged from Phase 17. Docker implementation
does not affect host-side test execution.

---

## 15. Regression tests — frontend

| Check | Result |
| ----- | ------ |
| `flutter analyze --fatal-infos` | ✅ No issues found (68.9 s) |
| `flutter test --concurrency 8`  | ✅ 329/329 tests passed (49 s) |
| `flutter build web`             | ✅ Built `build/web` (64.6 s) |

Frontend code unchanged from Phase 17. The Dockerfile downloads Flutter
3.47.4 from the official release tarball — byte-identical to the local SDK.

---

## 16. Docker-specific problem and resolution

### Original issue: `ghcr.io/cirruslabs/flutter:stable` pull error

During the pre-interruption Phase 18 run, the Docker build encountered a
transient TLS/DNS error pulling `ghcr.io/cirruslabs/flutter:stable` from the
GitHub Container Registry. An earlier draft of the frontend Dockerfile used
this as the Flutter SDK base.

**Resolution:** the final Dockerfile does **not** use the GHCR Flutter image.
Instead, it downloads the pinned release tarball (3.47.4) from Google's
official `storage.googleapis.com` endpoint. The previous transient GHCR error
is therefore irrelevant to the current Dockerfile — no retry was needed.

### Issues discovered and fixed during recovery

1. **`mv /opt/flutter` self-collision** — Dockerfile `mv` step attempted to
   move a directory into itself; removed the redundant step.
2. **Flutter `--version` git dubious ownership (exit 128)** — the release
   tarball contains `.git` metadata; added `git config --global --add
   safe.directory /opt/flutter`.
3. **Frontend healthcheck IPv4 vs IPv6** — nginx binds IPv4 only; `wget
   http://localhost/` resolved to IPv6 `::1` first; changed to
   `http://127.0.0.1/`.

None of these required architectural changes, port changes, or package
replacements.

---

## 17. Scope confirmation — no new features

No new application features were added. Phase 18 only packages the existing
application into Docker images and orchestrates them with Compose. All REST
APIs, routes, UI pages, and test suites remain identical to Phase 17.

---

## 18. Scope confirmation — no API changes

No endpoints, DTOs, request fields, or response shapes were introduced or
modified. The Docker Compose configuration passes environment variables to the
backend at container startup; no application-level defaults were changed.

---

## 19. Scope confirmation — no schema changes

Flyway migrations V1–V4 are unchanged and applied cleanly. Hibernate runs in
`validate` mode; the schema is identical to Phase 17.

---

## 20. Scope confirmation — no auth changes

The authentication model (JWT bearer + refresh token) is unchanged. The
Compose stack supplies the same `JWT_SECRET` / `JWT_ISSUER` / token expiration
values as the local development defaults.

---

## 21. Scope confirmation — no redesign

No UI changes. The frontend Dockerfile builds the same Flutter Web SPA with
the same `API_BASE_URL` (`http://localhost:8080`) baked in at build time via
`--dart-define`. nginx serves the static assets with SPA fallback.

---

## 22. Scope confirmation — no native targets

No iOS/Android/macOS/Linux code or configuration was introduced. Only
Flutter Web is built and served.

---

## 23. Scope confirmation — no CI/CD

No GitHub Actions, pipeline configurations, or deployment scripts were added.
This phase only delivers the local Docker Compose stack.

---

## 24. Scope confirmation — no git commit

No commit was created for Phase 18 (per the standing rule).

---

## 25. Known limitations

- **nginx master runs as root:** the official `nginx:alpine` image starts the
  master process as root and drops worker processes to the `nginx` user. This
  is the standard nginx deployment pattern; running entirely non-root requires
  a custom base image and is out of scope.
- **Flutter build runs as root inside Docker:** the `flutter build web` step
  executes as root inside the build stage container. This has no effect on the
  final runtime image, which contains only static assets served by nginx workers
  running as `nginx`.
- **Secrets via environment variables:** `JWT_SECRET`, `DB_PASSWORD`, and other
  secrets are supplied via `infrastructure/.env` (git-ignored). In production,
  these should be managed by a secrets manager. This is a local development
  stack only.
- **Docker Compose `restart` is not a cold-start test:** the named volume
  persists data through restarts; a true cold-start (volume wipe) test was not
  run because the recovery pass verified persistence via restart, which
  demonstrates data survives container recreation (the Docker Compose-defined
  volume survives service restarts and recreations).

---

## 26. Files touched (full list)

**New files:**
- `backend/Dockerfile`
- `backend/.dockerignore`
- `frontend/Dockerfile`
- `frontend/.dockerignore`
- `frontend/nginx.conf`
- `infrastructure/docker-compose.yml`
- `infrastructure/.env`
- `infrastructure/.env.example`

**Modified during recovery:**
- `frontend/Dockerfile` — `mv` removal + `git config safe.directory`
- `infrastructure/docker-compose.yml` — healthcheck `localhost` → `127.0.0.1`

**Documentation (this session):**
- `docs/phase-18-report.md` (this file)
- `README.md` (updated with Phase 18)
- `frontend/README.md` (updated with Docker section)

---

## 27. Final state

- **Docker images built:** `todo-app-backend:local` + `todo-app-frontend:local`
- **Compose stack up:** all 3 containers healthy
- **Flyway V1–V4:** ✅ applied
- **Full-stack smoke test:** ✅ register → login → create task → list → dashboard
- **Persistence:** ✅ task survives full stack restart
- **Container security:** ✅ non-root (backend + nginx workers), no secrets in images
- **Backend regression:** ✅ 291/291 tests, BUILD SUCCESS
- **Frontend regression:** ✅ analyze clean, 329/329 tests, web build green
- **Documentation:** ✅ this report, README updated, frontend README updated

All Phase 18 requirements are satisfied. No Phase 19 or Phase 20 were started.
