package com.todoapp.service;

import com.todoapp.entity.RefreshToken;
import com.todoapp.entity.User;
import com.todoapp.exception.ExpiredRefreshTokenException;
import com.todoapp.exception.InvalidRefreshTokenException;
import com.todoapp.repository.RefreshTokenRepository;
import com.todoapp.security.config.JwtSettings;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTest {

    private static final Instant NOW = Instant.parse("2026-01-01T00:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);
    private static final JwtSettings SETTINGS = new JwtSettings(
            "0123456789012345678901234567890123456789",
            "todo-app", Duration.ofMinutes(15), Duration.ofDays(30));

    @Mock
    private RefreshTokenRepository repository;

    private RefreshTokenService service() {
        return new RefreshTokenService(repository, SETTINGS, CLOCK);
    }

    @Test
    void issuePersistsOnlyTheHashAndAppliesTtl() {
        User user = new User("ada", "ada@example.com", "hash");

        String token = service().issue(user);

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(repository).save(captor.capture());
        RefreshToken saved = captor.getValue();

        assertThat(token).matches("[A-Za-z0-9_-]{64}");
        assertThat(saved.getTokenHash()).isNotEqualTo(token);
        assertThat(saved.getTokenHash()).hasSize(64);
        assertThat(saved.getExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
        assertThat(saved.getUser()).isSameAs(user);
        assertThat(saved.isRevoked()).isFalse();
    }

    @Test
    void authenticateAndRevokeReturnsUserAndPreservesCeiling() {
        User user = new User("ada", "ada@example.com", "hash");
        RefreshToken stored = new RefreshToken(NOW.plus(Duration.ofDays(10)), user, "hash-value");
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));

        RefreshTokenService.Session session = service().authenticateAndRevoke("raw-token");

        assertThat(session.user()).isSameAs(user);
        assertThat(session.expiresAtCeiling()).isEqualTo(stored.getExpiresAt());
        assertThat(stored.isRevoked()).isTrue();
        assertThat(stored.getLastUsedAt()).isEqualTo(NOW);
    }

    @Test
    void revokedTokenIsRejectedAsInvalid() {
        User user = new User("ada", "ada@example.com", "hash");
        RefreshToken stored = new RefreshToken(NOW.plusSeconds(60), user, "hash-value");
        stored.setRevokedAt(NOW);
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));

        assertThatThrownBy(() -> service().authenticateAndRevoke("raw-token"))
                .isInstanceOf(InvalidRefreshTokenException.class);
    }

    @Test
    void expiredTokenIsRejectedAsExpired() {
        User user = new User("ada", "ada@example.com", "hash");
        RefreshToken stored = new RefreshToken(NOW.minusSeconds(1), user, "hash-value");
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));

        assertThatThrownBy(() -> service().authenticateAndRevoke("raw-token"))
                .isInstanceOf(ExpiredRefreshTokenException.class);
    }

    @Test
    void unknownTokenIsRejectedAsInvalid() {
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().authenticateAndRevoke("unknown"))
                .isInstanceOf(InvalidRefreshTokenException.class);
    }

    @Test
    void blankTokenIsRejectedWithoutHittingRepository() {
        assertThatThrownBy(() -> service().authenticateAndRevoke("   "))
                .isInstanceOf(InvalidRefreshTokenException.class);

        verify(repository, never()).findByTokenHash(anyString());
    }

    @Test
    void revokeMarksKnownTokenRevoked() {
        User user = new User("ada", "ada@example.com", "hash");
        RefreshToken stored = new RefreshToken(NOW.plusSeconds(60), user, "hash-value");
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.of(stored));

        service().revoke("raw-token");

        assertThat(stored.isRevoked()).isTrue();
    }

    @Test
    void revokeIsIdempotentForUnknownTokens() {
        when(repository.findByTokenHash(anyString())).thenReturn(Optional.empty());

        service().revoke("unknown");

        verify(repository).findByTokenHash(anyString());
    }

    @Test
    void revokeNullIsANoOp() {
        service().revoke(null);

        verify(repository, never()).findByTokenHash(anyString());
    }
}