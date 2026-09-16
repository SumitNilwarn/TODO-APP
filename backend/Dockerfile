# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# backend — Todo App REST API (Java 21 / Spring Boot 3.5)
#
# Multi-stage build:
#   build  -> maven:3.9-eclipse-temurin-21 compiles the Spring Boot fat jar
#   runtime-> eclipse-temurin:21-jre-alpine executes it as the non-root `todo`
#             user. Only the built jar is copied; no source, no Maven cache,
#             no development tools in the final image.
# ---------------------------------------------------------------------------

# ---------------- build stage ----------------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Resolve dependencies first so source changes reuse the cached layer.
COPY pom.xml ./
RUN mvn -B -q -DskipTests dependency:go-offline

# Copy and compile the application (excludes tests inside the image:
# tests are executed on the host via `mvnw.cmd verify` — Phase 17 gate).
COPY src ./src
RUN mvn -B -q -DskipTests package

# ---------------- runtime stage ----------------
FROM eclipse-temurin:21-jre-alpine
LABEL org.opencontainers.image.title="todo-app-backend" \
      org.opencontainers.image.description="Todo App REST API (Spring Boot 3.5 / Java 21)" \
      org.opencontainers.image.source="https://github.com/local/todo-app"

# Non-root runtime user; Alpine provides busybox wget for healthchecks.
RUN addgroup -S todo && adduser -S todo -G todo

WORKDIR /app

# Spring Boot executable jar from the build stage.
COPY --from=build /workspace/target/todo-app-backend-0.1.0-SNAPSHOT.jar ./app.jar

RUN chown -R todo:todo /app

USER todo:todo

EXPOSE 8080

# Configuration is environment-driven at runtime (see application.yml).
# No credentials are baked into the image.
ENV SERVER_PORT=${PORT:-8080}

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
