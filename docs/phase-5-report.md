# Phase 5 Implementation Report — User Profile API

> Delivered: 2026-09-14 · Backend implementation complete, verified, and
> documented. This report is stored as `docs/phase-5-report.md` for future
> reference.

## 1. Scope

Caller-owned **user profile backend API** only. The Phase 4 JWT/security chain
is reused unchanged; no new Flyway migration (reuses `user_profiles` from `V2`);
no task/dashboard/Flutter work; no commits.

## 2. Endpoints (all require a Bearer access token; owner always from principal)

| Endpoint                    | Semantics                                                                |
| --------------------------- | ------------------------------------------------------------------------ |
| `GET /api/v1/profile`       | Returns the caller's profile → 200, or `404 PROFILE_NOT_FOUND`.          |
| `PUT /api/v1/profile`       | **Full replacement / upsert.** All five fields replaced by the body; `null` clears a field; blank rejected. 201 on create, 200 on replace. |
| `PATCH /api/v1/profile`     | **Partial update.** Omitted field untouched, explicit `null` clears, `{}` is a no-op; `404` when no profile exists. |

Fields (all optional; a fully empty profile is allowed):

| Field             | Limits          | Notes                                              |
| ----------------- | --------------- | -------------------------------------------------- |
| `firstName`       | ≤ 50 chars      | `null` clears · blank rejected                     |
| `lastName`        | ≤ 50 chars      | `null` clears · blank rejected                     |
| `displayName`     | ≤ 100 chars     | `null` clears · blank rejected                     |
| `timezone`        | ≤ 64 chars      | strict IANA id (`UTC`, `GMT`, `Us/Eastern`, …)     |
| `profileImageUrl` | ≤ 255 chars     | absolute `http(s)` URL with host                   |

Response payload (`ProfileResponse`): `userId`, `firstName`, `lastName`,
`displayName`, `timezone`, `profileImageUrl`, `createdAt`, `updatedAt`,
`version`.

## 3. Security

- **IDOR-safe by construction.** No `{profileId}` path segment, no user-id
  query parameter, and the request body is never trusted to carry identity.
  The owner is the `AuthenticatedUser` principal loaded by
  `JwtAuthenticationFilter` (which also requires an `ACTIVE` account every
  request — disabled/locked → `401 TOKEN_INVALID`).
- Unknown JSON fields (e.g. a spoofed `userId`) are silently ignored; the
  write always lands on the token owner (proven by `ProfileApiIT`).
- Responses are DTO-only; the `User` entity (incl. `passwordHash`) is never
  serialized.

## 4. Validation (two-tiered, one error envelope)

- **PUT:** declarative bean validation on `ProfileUpdateRequest`
  (`@NotBlankOrNull`, `@Size`, `@ValidTimezone`, `@ValidHttpUrl`).
- **PATCH:** programmatic validation in `ProfileService` using the same rules
  via a `PatchField` sentinel (`absent` / `null`(clear) / `value`).
- Both return `400 VALIDATION_ERROR` with `details: [{field, message}]`.
- Values are **trimmed** before persistence.

### Notable find

Hibernate Validator 8's `@NotBlank` **rejects `null`** in this stack
(verified empirically), which broke "null → clear". Replaced with the custom
`NotBlankOrNull` ("clear-via-null, reject blank").

### New custom constraints (`com.todoapp.validation`)

- `ValidTimezone` / `TimezoneValidator` — strict IANA ids
  (`ZoneId.getAvailableZoneIds()` + `UTC/GMT/UT/GMT0/UT0/Etc/UTC`); `EST`, `PST`,
  `GMT+05:30`, `Banana/Island` rejected.
- `ValidHttpUrl` / `HttpUrlValidator` — absolute `http(s)` URL with a non-empty
  host; relative paths and `javascript:` scheme rejected.
- `NotBlankOrNull` / `NotBlankOrNullValidator`.

## 5. Errors added (`GlobalExceptionHandler`)

| Code                    | Status | Meaning                                  |
| ----------------------- | ------ | ---------------------------------------- |
| `PROFILE_NOT_FOUND`     | 404    | Caller has no profile yet                 |
| `OPTIMISTIC_LOCK_CONFLICT` | 409  | `@Version` write conflict                 |
| `CONFLICT`              | 409    | Data-integrity conflict (e.g. duplicate) |

## 6. Key implementation notes

- Identity resolution: `ProfileService.getOwnProfile(principal)` /
  `updateProfile(principal, request)` / `patchProfile(principal, request)` —
  no id parameter anywhere.
- Mutations call `saveAndFlush` so auditing timestamps and `version` are
  populated in the response deterministically.
- Optimistic locking preserved (`@Version` on `BaseEntity`): stale concurrent
  writers receive `409 OPTIMISTIC_LOCK_CONFLICT`.
- The PATCH request DTO is a **POJO** (not a record) because Jackson records
  leave both *absent* and *explicit-null* as `null`; the custom
  `PatchFieldDeserializer` + setters distinguish the three states.
- `ApiPaths.PROFILE` added; `SecurityConfig` registers
  `requestMatchers(ApiPaths.PROFILE + "/**").authenticated()`.
- `/api/v1/profile/**` is thus protected by the same chain as auth; no
  migration was needed — `user_profiles` already exists (V2).

## 7. Tests

- **Unit (68):** `ProfileServiceTest` (13), `ProfilePatchRequestJsonTest` (3),
  `TimezoneValidatorTest` (3), `GlobalExceptionHandlerTest` (+3 handlers), plus
  existing Phase 3–4 suites.
- **Integration (83):** new `ProfileApiIT` (16 tests) covering:
  - create → GET; replace + version bump; partial PATCH; explicit-null clear;
    `{}` no-op; PATCH before profile → 404;
  - unauthenticated → 401; disabled/locked → 401 `TOKEN_INVALID`;
  - cross-user isolation (A cannot see/modify B); spoofed `userId` in body is
    ignored, write lands on owner; B has no profile;
  - PUT/PATCH validation envelopes; persistence + auditing + versioning.
  - Reuses the existing `AuthIntegrationIT` (17), repository ITs, and schema ITs.
- **Verification:** `mvnw clean verify` → **BUILD SUCCESS** (68 unit + 83 IT);
  `docker compose config --quiet` → OK (in `infrastructure/`).

## 8. Documentation updated

- `docs/api-overview.md` — status banner, implemented-endpoint tables, new §1b
  Profile endpoints section, new error codes.
- `docs/architecture.md` — scope banner (Phases 4–5), new §3.2 Profile service.
- `docs/security.md` — intro (Phases 4–5), §8b Profile authorization/ownership,
  new §9 Phase 5 non-goals (renumbered afterwards).
- `docs/development-workflow.md` — profile conventions + IT coverage note.
- `README.md` — status banner → Phase 5; docs list.
- `OpenApiConfig` description updated.

## 9. Non-goals (explicit, respected)

- No task CRUD, dashboard, password-reset, or email-verification functionality.
- No profile-image upload/storage (external URL only).
- No admin/user-management APIs.
- No Flutter changes; no new database migration; no commits.