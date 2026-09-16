# Spring Security package

Phase 4 implements full stateless JWT authentication. The package owns the
security chain, the JWT filter, the principal, and the filter-stage error
writing.

## Package layout

```
com.todoapp.security
├── config/SecurityConfig.java        # SecurityFilterChain (stateless, JWT filter wiring)
├── config/JwtSettings.java           # Immutable JWT config (secret, issuer, TTLs)
├── filter/JwtAuthenticationFilter.java  # Bearer-token auth (constructed in SecurityConfig)
├── principal/AuthenticatedUser.java  # Lightweight caller principal (userId, username)
├── RestAuthenticationEntryPoint.java # Writes 401 ApiError at the filter stage
├── RestAccessDeniedHandler.java      # Writes 403 ApiError at the filter stage
└── TokenAuthenticationException.java # Filter-stage auth failure with stable code
```

Supporting beans live in `com.todoapp.configuration.JwtConfig` (JwtSettings,
system `Clock`, `PasswordEncoder`) and the crypto/service logic in
`com.todoapp.service` (`JwtService`, `PasswordService`, `RefreshTokenService`,
`AuthService`).

## Design notes

- The JWT filter is **not** a Spring component; `SecurityConfig` creates it with
  `new JwtAuthenticationFilter(...)`. Annotating it with `@Component` would make
  Spring Boot register a second instance on the default filter chain.
- Invalid Bearer tokens are written as a 401 `ApiError` via the entry point that
  is passed into the filter. This filter runs after `ExceptionTranslationFilter`,
  so re-throwing would surface as a 500; controller-stage errors instead flow
  through `GlobalExceptionHandler`.
- The full threat model, token lifecycle and operational checklist are documented
  in `docs/security.md`.