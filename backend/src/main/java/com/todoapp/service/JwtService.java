package com.todoapp.service;

import com.todoapp.security.TokenAuthenticationException;
import com.todoapp.security.config.JwtSettings;
import com.todoapp.security.principal.AuthenticatedUser;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;

/**
 * Issues and validates HMAC-SHA256-signed JWT access tokens.
 *
 * <p>A plain, Spring-free class (constructed by {@link com.todoapp.configuration.JwtConfig})
 * so it can be unit-tested in isolation with any {@link Clock}. Claims are
 * deliberately minimal — identity only, no sensitive data:
 * {@code sub}=userId, {@code iss}, {@code iat}, {@code exp}, {@code username}.</p>
 *
 * <p>Validation failures are normalized into {@link TokenAuthenticationException}
 * with a stable code so callers can distinguish expired from otherwise-invalid
 * tokens without leaking implementation details to the client.</p>
 */
public class JwtService {

    private static final String USERNAME_CLAIM = "username";

    private final JwtSettings settings;
    private final SecretKey key;
    private final Clock clock;

    public JwtService(JwtSettings settings, Clock clock) {
        this.settings = settings;
        this.key = Keys.hmacShaKeyFor(settings.secret().getBytes(StandardCharsets.UTF_8));
        this.clock = clock;
    }

    /**
     * Creates a signed access token for the given identity, valid for
     * {@code settings.accessTokenTtl()}.
     */
    public String createAccessToken(UUID userId, String username) {
        Date now = Date.from(clock.instant());
        Date expiresAt = Date.from(clock.instant().plus(settings.accessTokenTtl()));
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuer(settings.issuer())
                .claim(USERNAME_CLAIM, username)
                .issuedAt(now)
                .expiration(expiresAt)
                .signWith(key)
                .compact();
    }

    /**
     * Verifies signature, issuer and expiry, then extracts the principal.
     *
     * @throws TokenAuthenticationException with {@code TOKEN_EXPIRED} if the token
     *         has expired, or {@code TOKEN_INVALID} if it is malformed/forged.
     */
    public AuthenticatedUser parseAccessToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .requireIssuer(settings.issuer())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return new AuthenticatedUser(
                    UUID.fromString(claims.getSubject()),
                    claims.get(USERNAME_CLAIM, String.class));
        } catch (ExpiredJwtException ex) {
            throw new TokenAuthenticationException("TOKEN_EXPIRED", "Access token has expired", ex);
        } catch (JwtException | IllegalArgumentException ex) {
            throw new TokenAuthenticationException("TOKEN_INVALID", "Access token is invalid", ex);
        }
    }
}