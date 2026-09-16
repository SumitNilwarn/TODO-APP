# features/auth

Authentication feature module.

## Presentation (Phase 9 — routes reserved, screens are placeholders)

- `presentation/login_page.dart` — placeholder for `/login`
- `presentation/register_page.dart` — placeholder for `/register`

## Planned contents (later phases, not implemented)

- `data/` — auth repository over the foundation `ApiClient`
  (`POST /api/v1/auth/register|login|refresh|logout`, `GET /api/v1/auth/me`)
- `domain/` — session model, auth state without fake authentication
- `presentation/` — real login/registration forms and auth guards