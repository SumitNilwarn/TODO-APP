package com.todoapp.service;

import com.todoapp.dto.auth.CurrentUserResponse;
import com.todoapp.dto.auth.LoginRequest;
import com.todoapp.dto.auth.RegisterRequest;
import com.todoapp.dto.auth.RegisterResponse;
import com.todoapp.dto.auth.TokenResponse;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.User;
import com.todoapp.exception.AccountDisabledException;
import com.todoapp.exception.AccountLockedException;
import com.todoapp.exception.AuthenticationFailedException;
import com.todoapp.exception.EmailAlreadyTakenException;
import com.todoapp.exception.UsernameAlreadyTakenException;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.config.JwtSettings;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);
    private static final JwtSettings SETTINGS = new JwtSettings(
            "0123456789012345678901234567890123456789",
            "todo-app", Duration.ofSeconds(900), Duration.ofDays(30));

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordService passwordService;
    @Mock
    private JwtService jwtService;
    @Mock
    private RefreshTokenService refreshTokenService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordService, jwtService,
                refreshTokenService, SETTINGS, CLOCK);
    }

    @Test
    void registerNormalizesIdentityAndReturnsIt() {
        when(userRepository.existsByUsername("ada")).thenReturn(false);
        when(userRepository.existsByEmail("ada@example.com")).thenReturn(false);
        when(passwordService.hash("S3cure-pass-42!")).thenReturn("hash");
        when(userRepository.saveAndFlush(any(User.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        RegisterResponse response = authService.register(
                new RegisterRequest("  Ada ", "  ADA@Example.COM ", "S3cure-pass-42!"));

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).saveAndFlush(captor.capture());
        assertThat(captor.getValue().getUsername()).isEqualTo("ada");
        assertThat(captor.getValue().getEmail()).isEqualTo("ada@example.com");
        assertThat(captor.getValue().getPasswordHash()).isEqualTo("hash");
        assertThat(response.username()).isEqualTo("ada");
    }

    @Test
    void registerRejectsTakenUsername() {
        when(userRepository.existsByUsername("ada")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(
                new RegisterRequest("ada", "ada@example.com", "S3cure-pass-42!")))
                .isInstanceOf(UsernameAlreadyTakenException.class);

        verify(userRepository, never()).saveAndFlush(any());
    }

    @Test
    void registerRejectsTakenEmail() {
        when(userRepository.existsByUsername("ada")).thenReturn(false);
        when(userRepository.existsByEmail("ada@example.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(
                new RegisterRequest("ada", "ada@example.com", "S3cure-pass-42!")))
                .isInstanceOf(EmailAlreadyTakenException.class);

        verify(userRepository, never()).saveAndFlush(any());
    }

    @Test
    void loginSucceedsWithUsernameAndUpdatesLastLoginAt() {
        User user = new User("ada", "ada@example.com", "hash");
        when(userRepository.findByUsername("ada")).thenReturn(Optional.of(user));
        when(passwordService.matches("S3cure-pass-42!", "hash")).thenReturn(true);
        when(refreshTokenService.issue(user)).thenReturn("refresh-token");
        when(jwtService.createAccessToken(any(), any())).thenReturn("jwt");

        TokenResponse response = authService.login(
                new LoginRequest("Ada", "S3cure-pass-42!"));

        assertThat(response.accessToken()).isEqualTo("jwt");
        assertThat(response.refreshToken()).isEqualTo("refresh-token");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(900);
        assertThat(user.getLastLoginAt()).isEqualTo(CLOCK.instant());
    }

    @Test
    void loginSucceedsWithEmail() {
        User user = new User("ada", "ada@example.com", "hash");
        when(userRepository.findByUsername("ada@example.com")).thenReturn(Optional.empty());
        when(userRepository.findByEmail("ada@example.com")).thenReturn(Optional.of(user));
        when(passwordService.matches("S3cure-pass-42!", "hash")).thenReturn(true);
        when(refreshTokenService.issue(user)).thenReturn("refresh-token");
        when(jwtService.createAccessToken(any(), any())).thenReturn("jwt");

        TokenResponse response = authService.login(
                new LoginRequest("ADA@example.com", "S3cure-pass-42!"));

        assertThat(response.refreshToken()).isEqualTo("refresh-token");
    }

    @Test
    void loginWithUnknownUserFailsGenerically() {
        when(userRepository.findByUsername("unknown")).thenReturn(Optional.empty());
        when(userRepository.findByEmail("unknown")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("unknown", "S3cure-pass-42!")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void loginWithWrongPasswordFailsGenericially() {
        User user = new User("ada", "ada@example.com", "hash");
        when(userRepository.findByUsername("ada")).thenReturn(Optional.of(user));
        when(passwordService.matches("wrong", "hash")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("ada", "wrong")))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void loginRejectsDisabledAccount() {
        User user = new User("ada", "ada@example.com", "hash");
        user.setAccountStatus(AccountStatus.DISABLED);
        when(userRepository.findByUsername("ada")).thenReturn(Optional.of(user));
        when(passwordService.matches("S3cure-pass-42!", "hash")).thenReturn(true);

        assertThatThrownBy(() -> authService.login(new LoginRequest("ada", "S3cure-pass-42!")))
                .isInstanceOf(AccountDisabledException.class);
    }

    @Test
    void loginRejectsLockedAccount() {
        User user = new User("ada", "ada@example.com", "hash");
        user.setAccountStatus(AccountStatus.LOCKED);
        when(userRepository.findByUsername("ada")).thenReturn(Optional.of(user));
        when(passwordService.matches("S3cure-pass-42!", "hash")).thenReturn(true);

        assertThatThrownBy(() -> authService.login(new LoginRequest("ada", "S3cure-pass-42!")))
                .isInstanceOf(AccountLockedException.class);
    }

    @Test
    void refreshRotatesTokensAndPreservesExpiryCeiling() {
        User user = new User("ada", "ada@example.com", "hash");
        RefreshTokenService.Session session =
                new RefreshTokenService.Session(user, Instant.parse("2026-01-15T00:00:00Z"));
        when(refreshTokenService.authenticateAndRevoke("old-raw")).thenReturn(session);
        when(refreshTokenService.issue(user, session.expiresAtCeiling())).thenReturn("new-raw");
        when(jwtService.createAccessToken(any(), any())).thenReturn("jwt");

        TokenResponse response = authService.refresh("old-raw");

        assertThat(response.accessToken()).isEqualTo("jwt");
        assertThat(response.refreshToken()).isEqualTo("new-raw");
    }

    @Test
    void refreshRejectsDisabledAccountWithoutIssuing() {
        User user = new User("ada", "ada@example.com", "hash");
        user.setAccountStatus(AccountStatus.DISABLED);
        RefreshTokenService.Session session =
                new RefreshTokenService.Session(user, Instant.parse("2026-01-15T00:00:00Z"));
        when(refreshTokenService.authenticateAndRevoke("old-raw")).thenReturn(session);

        assertThatThrownBy(() -> authService.refresh("old-raw"))
                .isInstanceOf(AccountDisabledException.class);

        verify(refreshTokenService, never()).issue(any(), any());
    }

    @Test
    void logoutDelegatesToRefreshTokenService() {
        authService.logout("raw-token");

        verify(refreshTokenService).revoke("raw-token");
    }

    @Test
    void currentUserReturnsIdentityWithoutPasswordHash() {
        UUID userId = UUID.randomUUID();
        User user = new User("ada", "ada@example.com", "hash");
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));

        CurrentUserResponse response =
                authService.currentUser(new AuthenticatedUser(userId, "ada"));

        assertThat(response.userId()).isEqualTo(user.getId());
        assertThat(response.username()).isEqualTo("ada");
        assertThat(response.email()).isEqualTo("ada@example.com");
    }

    @Test
    void currentUserThrowsWhenAccountVanished() {
        when(userRepository.findById(any(UUID.class))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.currentUser(
                new AuthenticatedUser(UUID.randomUUID(), "ada")))
                .isInstanceOf(AuthenticationFailedException.class);
    }
}