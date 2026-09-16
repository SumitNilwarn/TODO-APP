package com.todoapp.security.config;

import java.time.Duration;

/**
 * Immutable, environment-driven JWT configuration.
 *
 * <p>{@code secret} is the raw HMAC-SHA256 key material (read via the
 * {@code app.security.jwt.secret} property which maps to the {@code JWT_SECRET}
 * environment variable). The JWT service derives the cryptographic key from it.
 * TTLs are expressed as durations so call sites stay readable.</p>
 */
public record JwtSettings(String secret, String issuer,
                          Duration accessTokenTtl, Duration refreshTokenTtl) {
}