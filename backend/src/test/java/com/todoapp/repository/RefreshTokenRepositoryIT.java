package com.todoapp.repository;

import com.todoapp.configuration.JpaAuditingConfig;
import com.todoapp.entity.RefreshToken;
import com.todoapp.entity.User;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(JpaAuditingConfig.class)
@Testcontainers
class RefreshTokenRepositoryIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EntityManager entityManager;

    private User createUser(String username) {
        return userRepository.saveAndFlush(
                new User(username, username + "@example.com", "encoded-hash"));
    }

    private static String hash(String value) {
        return java.util.HexFormat.of().formatHex(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    @Test
    void sessionCanBePersistedAndFoundByHash() {
        User user = createUser("ada");
        Instant expiresAt = Instant.now().plusSeconds(60);
        String tokenHash = hash("ada-token");

        RefreshToken saved =
                refreshTokenRepository.saveAndFlush(new RefreshToken(expiresAt, user, tokenHash));

        RefreshToken found = refreshTokenRepository.findByTokenHash(tokenHash).orElseThrow();
        assertThat(found.getId()).isEqualTo(saved.getId());
        assertThat(found.getExpiresAt()).isEqualTo(expiresAt);
        assertThat(found.getUser().getId()).isEqualTo(user.getId());
        assertThat(found.isRevoked()).isFalse();
        assertThat(found.isExpired(Instant.now())).isFalse();
    }

    @Test
    void tokenHashIsUniqueAcrossUsers() {
        User user = createUser("bob");
        String tokenHash = hash("bob-token");
        refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, tokenHash));

        assertThatThrownBy(() -> refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, tokenHash)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void revocationIsPersisted() {
        User user = createUser("carol");
        String tokenHash = hash("carol-token");
        RefreshToken token =
                refreshTokenRepository.saveAndFlush(new RefreshToken(Instant.now().plusSeconds(60), user, tokenHash));

        token.setRevokedAt(Instant.now());
        refreshTokenRepository.saveAndFlush(token);

        RefreshToken reloaded = refreshTokenRepository.findByTokenHash(tokenHash).orElseThrow();
        assertThat(reloaded.isRevoked()).isTrue();
    }

    @Test
    void deletingUserCascadesToAllSessions() {
        User user = createUser("eve");
        refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, hash("eve-token-1")));
        refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, hash("eve-token-2")));

        assertThat(refreshTokenRepository.countByUserId(user.getId())).isEqualTo(2);

        entityManager.createQuery("delete from User u where u.id = :id")
                .setParameter("id", user.getId())
                .executeUpdate();
        entityManager.flush();
        entityManager.clear();

        assertThat(refreshTokenRepository.countByUserId(user.getId())).isZero();
    }

    @Test
    void tokenHashCannotBeNull() {
        User user = createUser("frank");
        assertThatThrownBy(() -> refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, null)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void expiresAtCannotBeNull() {
        User user = createUser("grace");
        assertThatThrownBy(() -> refreshTokenRepository.saveAndFlush(
                new RefreshToken(null, user, hash("grace-token"))))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void auditingPopulatesTimestamps() {
        User user = createUser("ping");
        RefreshToken saved = refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().plusSeconds(60), user, hash("ping-token")));

        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }
}