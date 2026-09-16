package com.todoapp.service;

import com.todoapp.entity.RefreshToken;
import com.todoapp.entity.User;
import com.todoapp.exception.ExpiredRefreshTokenException;
import com.todoapp.exception.InvalidRefreshTokenException;
import com.todoapp.repository.RefreshTokenRepository;
import com.todoapp.security.config.JwtSettings;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Issues, rotates and revokes persisted refresh-token sessions.
 *
 * <p>Each refresh token is an opaque 256-bit random value, delivered to the
 * client exactly once and stored server-side <em>only</em> as its SHA-256 hex
 * digest. Rows carry {@code expiresAt} (a hard ceiling set at issue time) and
 * {@code revokedAt}, so a token is enforceable as single-use with a bounded
 * lifetime: a successful refresh authenticates the presented token, revokes it,
 * and issues a replacement whose {@code expiresAt} never extends past the
 * original ceiling. Replaying an old token therefore yields
 * {@link InvalidRefreshTokenException}.</p>
 */
@Service
public class RefreshTokenService {

    private static final int REFRESH_TOKEN_BYTES = 48;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtSettings settings;
    private final Clock clock;

    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository,
                               JwtSettings settings, Clock clock) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.settings = settings;
        this.clock = clock;
    }

    /** Issues a new session expiring {@code settings.refreshTokenTtl()} from now. */
    @Transactional
    public String issue(User user) {
        return issue(user, clock.instant().plus(settings.refreshTokenTtl()));
    }

    /** Issues a new session with an explicit expiry ceiling (used on rotation). */
    @Transactional
    public String issue(User user, Instant expiresAt) {
        byte[] raw = new byte[REFRESH_TOKEN_BYTES];
        SECURE_RANDOM.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        refreshTokenRepository.save(new RefreshToken(expiresAt, user, hash(token)));
        return token;
    }

    /**
     * Validates the presented token and revokes it. A revoked/unknown token fails
     * with {@link InvalidRefreshTokenException}; an expired one fails with
     * {@link ExpiredRefreshTokenException}.
     *
     * @return the owning user and the original expiry ceiling, to preserve it on
     *         the rotated replacement
     */
    @Transactional
    public Session authenticateAndRevoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new InvalidRefreshTokenException();
        }
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash(rawToken))
                .orElseThrow(InvalidRefreshTokenException::new);
        if (stored.isRevoked()) {
            throw new InvalidRefreshTokenException();
        }
        Instant now = clock.instant();
        if (stored.isExpired(now)) {
            throw new ExpiredRefreshTokenException();
        }
        User user = stored.getUser();
        stored.setLastUsedAt(now);
        stored.setRevokedAt(now);
        return new Session(user, stored.getExpiresAt());
    }

    /**
     * Revokes the token for logout. Idempotent and never throws for unknown or
     * already-revoked tokens so logout always "succeeds" from the client's view.
     */
    @Transactional
    public void revoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return;
        }
        refreshTokenRepository.findByTokenHash(hash(rawToken))
                .ifPresent(stored -> stored.setRevokedAt(clock.instant()));
    }

    private static String hash(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is not available", ex);
        }
    }

    /** Result of a successfully authenticated rotation step. */
    public record Session(User user, Instant expiresAtCeiling) {
    }
}