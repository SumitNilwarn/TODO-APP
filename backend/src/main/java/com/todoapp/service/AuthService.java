package com.todoapp.service;

import com.todoapp.dto.auth.CurrentUserResponse;
import com.todoapp.dto.auth.LoginRequest;
import com.todoapp.dto.auth.RegisterRequest;
import com.todoapp.dto.auth.RegisterResponse;
import com.todoapp.dto.auth.TokenResponse;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.User;
import com.todoapp.exception.AccountAlreadyExistsException;
import com.todoapp.exception.AccountDisabledException;
import com.todoapp.exception.AccountLockedException;
import com.todoapp.exception.AuthenticationFailedException;
import com.todoapp.exception.EmailAlreadyTakenException;
import com.todoapp.exception.UsernameAlreadyTakenException;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.config.JwtSettings;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.util.Locale;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Application-facing authentication flows: registration, login, token refresh,
 * logout and caller identity.
 *
 * <p>Design notes:</p>
 * <ul>
 *   <li>{@code register} pre-checks uniqueness then persists; a
 *       {@link DataIntegrityViolationException} from a concurrent request is
 *       translated into a generic 409 without leaking which field collided.</li>
 *   <li>{@code login} accepts a username <em>or</em> email (case-insensitive)
 *       and returns an opaque 401 for both unknown-credential and wrong-password
 *       to avoid account enumeration.</li>
 *   <li>{@code refresh} rotates the session, preserving the original expiry
 *       ceiling, and refuses non-{@code ACTIVE} accounts (rolling the rotation
 *       back via the transaction).</li>
 *   <li>{@code lastLoginAt} is updated only on successful login, never on
 *       refresh or token validation.</li>
 * </ul>
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordService passwordService;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final JwtSettings jwtSettings;
    private final Clock clock;

    public AuthService(UserRepository userRepository,
                       PasswordService passwordService,
                       JwtService jwtService,
                       RefreshTokenService refreshTokenService,
                       JwtSettings jwtSettings,
                       Clock clock) {
        this.userRepository = userRepository;
        this.passwordService = passwordService;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.jwtSettings = jwtSettings;
        this.clock = clock;
    }

    @Transactional
    public RegisterResponse register(RegisterRequest request) {
        String username = normalize(request.username());
        String email = normalize(request.email());
        if (userRepository.existsByUsername(username)) {
            throw new UsernameAlreadyTakenException();
        }
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyTakenException();
        }
        User user = new User(username, email, passwordService.hash(request.password()));
        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            throw new AccountAlreadyExistsException();
        }
        return new RegisterResponse(user.getId(), user.getUsername());
    }

    @Transactional
    public TokenResponse login(LoginRequest request) {
        String loginId = normalize(request.username());
        User user = findByIdentifier(loginId)
                .orElseThrow(AuthenticationFailedException::new);
        if (!passwordService.matches(request.password(), user.getPasswordHash())) {
            throw new AuthenticationFailedException();
        }
        requireActive(user);
        user.setLastLoginAt(clock.instant());
        return issueTokens(user, refreshTokenService.issue(user));
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshTokenService.Session session =
                refreshTokenService.authenticateAndRevoke(rawRefreshToken);
        requireActive(session.user());
        String rotated = refreshTokenService.issue(session.user(), session.expiresAtCeiling());
        return issueTokens(session.user(), rotated);
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }

    @Transactional(readOnly = true)
    public CurrentUserResponse currentUser(AuthenticatedUser principal) {
        User user = userRepository.findById(principal.userId())
                .orElseThrow(AuthenticationFailedException::new);
        return new CurrentUserResponse(user.getId(), user.getUsername(), user.getEmail());
    }

    private TokenResponse issueTokens(User user, String refreshToken) {
        return TokenResponse.of(
                jwtService.createAccessToken(user.getId(), user.getUsername()),
                refreshToken,
                jwtSettings.accessTokenTtl().toSeconds());
    }

    private static void requireActive(User user) {
        if (user.getAccountStatus() == AccountStatus.DISABLED) {
            throw new AccountDisabledException();
        }
        if (user.getAccountStatus() == AccountStatus.LOCKED) {
            throw new AccountLockedException();
        }
    }

    private java.util.Optional<User> findByIdentifier(String identifier) {
        return userRepository.findByUsername(identifier)
                .or(() -> userRepository.findByEmail(identifier));
    }

    private static String normalize(String value) {
        return value == null ? null : value.trim().toLowerCase(Locale.ROOT);
    }
}