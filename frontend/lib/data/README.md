# `data`

Global data / API plumbing shared across features.

## Implemented (Phase 9 — foundation)

- `api/api_client.dart` — `ApiClient`: thin JSON client over `package:http`
  with the base URL from `core/config/app_config.dart` (overridable),
  request/response/interceptor hooks, timeout handling and envelope parsing.
  Every request sends a fresh `X-Correlation-Id` (32-char random hex) that the
  backend echoes; the echo is captured on `ApiResponseData` and forwarded into
  server-error `ApiException`s alongside the top-level envelope `path`/
  `timestamp` (Phase 15).
- `api/api_envelope.dart` — raw `ApiResponse`/`ApiError` envelope model.
- `api/api_error.dart` — `ApiError` + `ApiErrorDetail` mirrors of the backend
  error envelope (`code`, `message`, `details`, `timestamp`, `path`).
- `api/api_response.dart` — typed `ApiResponse<T>` for success payloads.
- `api/api_exception.dart` — `ApiException` (server / network / timeout /
  invalid / unexpected) thrown for non-2xx or unreadable responses.
- `api/api_interceptor.dart` — `ApiInterceptor` + request/response metadata.
- `api/api_paths.dart` — versioned API path constant (`/api/v1`).

Nothing in this layer is feature-specific yet. Repositories for auth, profile,
tasks and dashboard are added in later phases and reuse `ApiClient`.

## Planned contents (later phases, not implemented)

- Feature repository implementations (register/login/refresh/logout, profile,
  tasks + queries, dashboard)
- Serialization models (mirrors of backend DTOs)
- Shared persistence/caching if ever needed