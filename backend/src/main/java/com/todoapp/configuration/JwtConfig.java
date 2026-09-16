package com.todoapp.configuration;

import com.todoapp.security.config.JwtSettings;
import com.todoapp.service.JwtService;
import java.time.Clock;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Security-supporting configuration beans: the JWT settings (driven by
 * {@code app.security.jwt.*}, i.e. the {@code JWT_*}, environment variables),
 * the {@link java.time.Clock} used for all token time computations, and the
 * BCrypt password encoder.
 *
 * <p>The signing secret is validated at startup so a mis-configured environment
 * fails fast instead of silently producing weak tokens.</p>
 */
@Configuration
public class JwtConfig {

    static final int MIN_SECRET_LENGTH = 32;

    @Bean
    JwtSettings jwtSettings(
            @Value("${app.security.jwt.secret}") String secret,
            @Value("${app.security.jwt.issuer}") String issuer,
            @Value("${app.security.jwt.access-token-expiration-seconds}") long accessSeconds,
            @Value("${app.security.jwt.refresh-token-expiration-seconds}") long refreshSeconds) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("app.security.jwt.secret (JWT_SECRET) must be configured");
        }
        if (secret.length() < MIN_SECRET_LENGTH) {
            throw new IllegalStateException("app.security.jwt.secret (JWT_SECRET) must be at least "
                    + MIN_SECRET_LENGTH + " characters for a strong HS256 key");
        }
        return new JwtSettings(secret, issuer,
                Duration.ofSeconds(accessSeconds), Duration.ofSeconds(refreshSeconds));
    }

    @Bean
    JwtService jwtService(JwtSettings settings, Clock clock) {
        return new JwtService(settings, clock);
    }

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}