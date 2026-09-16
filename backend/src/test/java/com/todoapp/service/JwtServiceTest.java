package com.todoapp.service;

import com.todoapp.security.TokenAuthenticationException;
import com.todoapp.security.config.JwtSettings;
import com.todoapp.security.principal.AuthenticatedUser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private static final String SECRET = "0123456789012345678901234567890123456789";
    private static final String ISSUER = "todo-app";

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(
                new JwtSettings(SECRET, ISSUER, Duration.ofMinutes(15), Duration.ofDays(30)),
                Clock.systemUTC());
    }

    @Test
    void issuedTokenParsesBackToOriginalPrincipal() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.createAccessToken(userId, "ada");

        AuthenticatedUser principal = jwtService.parseAccessToken(token);

        assertThat(principal.userId()).isEqualTo(userId);
        assertThat(principal.username()).isEqualTo("ada");
    }

    @Test
    void tamperedTokenIsRejectedAsInvalid() {
        String token = jwtService.createAccessToken(UUID.randomUUID(), "ada");
        String tampered = token.substring(0, token.length() - 2) + "xx";

        assertThatThrownBy(() -> jwtService.parseAccessToken(tampered))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_INVALID"));
    }

    @Test
    void tokenSignedWithAnotherKeyIsRejected() {
        JwtService otherKey = new JwtService(
                new JwtSettings("another-secret-another-secret-another-secret", ISSUER,
                        Duration.ofMinutes(15), Duration.ofDays(30)),
                Clock.systemUTC());
        String token = otherKey.createAccessToken(UUID.randomUUID(), "ada");

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_INVALID"));
    }

    @Test
    void expiredTokenIsRejectedAsExpired() {
        Instant then = Instant.now().minusSeconds(3600);
        JwtService pastService = new JwtService(
                new JwtSettings(SECRET, ISSUER, Duration.ofSeconds(30), Duration.ofDays(30)),
                Clock.fixed(then, ZoneOffset.UTC));
        String token = pastService.createAccessToken(UUID.randomUUID(), "ada");

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_EXPIRED"));
    }

    @Test
    void tokenWithWrongIssuerIsRejected() {
        JwtService otherIssuer = new JwtService(
                new JwtSettings(SECRET, "other-issuer", Duration.ofMinutes(15), Duration.ofDays(30)),
                Clock.systemUTC());
        String token = otherIssuer.createAccessToken(UUID.randomUUID(), "ada");

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOf(TokenAuthenticationException.class);
    }

    @Test
    void malformedTokenIsRejectedAsInvalid() {
        assertThatThrownBy(() -> jwtService.parseAccessToken("not-a-jwt"))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_INVALID"));
    }

    @Test
    void nullTokenIsRejectedAsInvalid() {
        assertThatThrownBy(() -> jwtService.parseAccessToken(null))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_INVALID"));
    }

    @Test
    void issuedTokenCarriesExpectedClaims() {
        UUID userId = UUID.randomUUID();
        JwtSettings settings = new JwtSettings(SECRET, ISSUER, Duration.ofMinutes(15), Duration.ofDays(30));
        JwtService service = new JwtService(settings, Clock.fixed(Instant.parse("2026-06-15T10:00:00Z"), ZoneOffset.UTC));
        String token = service.createAccessToken(userId, "ada");

        var claims = Jwts.parser()
                .verifyWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8)))
                .clock(() -> Date.from(Instant.parse("2026-06-15T10:00:00Z")))
                .build()
                .parseSignedClaims(token)
                .getPayload();

        assertThat(claims.getIssuer()).isEqualTo(ISSUER);
        assertThat(claims.getSubject()).isEqualTo(userId.toString());
        assertThat(claims.get("username", String.class)).isEqualTo("ada");
        assertThat(claims.getExpiration()).isEqualTo(Date.from(Instant.parse("2026-06-15T10:15:00Z")));
    }

    @Test
    void tokenWithNonUuidSubjectIsRejected() {
        String token = Jwts.builder()
                .subject("not-a-uuid")
                .issuer(ISSUER)
                .claim("username", "ada")
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(300)))
                .signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8)))
                .compact();

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOfSatisfying(TokenAuthenticationException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo("TOKEN_INVALID"));
    }
}