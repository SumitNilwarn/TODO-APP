# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# frontend — Todo App Flutter Web client (SPA served by nginx)
#
# Multi-stage build:
#   build   -> installs the EXACT pinned Flutter SDK release (3.47.4 stable /
#              Dart 3.13.3 — byte-identical to the local 3.47.4 toolchain that
#              passes Phase 17's 329-test gate) straight from Flutter's
#              official release tarball, then builds the Flutter Web release
#              SPA. The browser-accessible backend URL is injected at build
#              time via a --dart-define so the SPA can call
#              http://localhost:8080 (NEVER "http://backend:8080").
#   runtime -> nginx serves the static SPA with a fallback to /index.html so
#              browser refresh / deep-link navigation (/login, /register,
#              /profile, /dashboard, /tasks, /tasks/{id}, /design-system)
#              never returns a server 404.
# ---------------------------------------------------------------------------

# ---------------- build stage: Flutter Web ----------------
FROM debian:bookworm-slim AS build

# Minimal toolchain for the Download + untar of the pinned Flutter SDK.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        xz-utils \
        git \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Pin the Flutter release tarball to the exact stable release the project
# toolchain uses (3.47.4 → Dart 3.13.3). This matches the local SDK that
# passes Phase 17's gate; using cirruslabs "stable" (3.44.0/Dart 3.12.0)
# would violate pubspec's `sdk: ^3.13.3` constraint.
ARG FLUTTER_VERSION=3.47.4
ENV FLUTTER_ROOT=/opt/flutter
# Official Flutter release archive for Linux amd64 stable.
# https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/
# flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
RUN curl -fsSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm -f /tmp/flutter.tar.xz \
    && git config --global --add safe.directory "${FLUTTER_ROOT}" \
    && ${FLUTTER_ROOT}/bin/flutter --version >/dev/null 2>&1 \
    && ${FLUTTER_ROOT}/bin/flutter config --no-analytics

ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"
ENV PUB_CACHE=/tmp/pub-cache

WORKDIR /app

# Cache package resolution before copying sources.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Build with the browser-facing API base URL baked in via --dart-define.
COPY . .
ARG API_BASE_URL=http://localhost:8080
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# ---------------- runtime stage: nginx SPA ----------------
FROM nginx:1.27-alpine

# nginx listener config: SPA fallback routes non-file deep links (e.g.
# /login, /tasks/{id}) to /index.html; static assets served from disk.
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Built Flutter Web SPA (no source, no build tools) -> nginx docroot.
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
