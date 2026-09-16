package com.todoapp.repository;

import com.todoapp.configuration.JpaAuditingConfig;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.User;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
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
class UserRepositoryIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void userCanBePersistedAndReadBack() {
        User saved = userRepository.saveAndFlush(new User("ada", "ada@example.com", "encoded-hash"));

        assertThat(saved.getId()).isNotNull();
        assertThat(userRepository.findById(saved.getId())).isPresent();
        assertThat(userRepository.findByUsername("ada")).isPresent();
        assertThat(userRepository.findByEmail("ada@example.com")).isPresent();
        assertThat(userRepository.existsByUsername("ada")).isTrue();
        assertThat(userRepository.existsByEmail("ada@example.com")).isTrue();
    }

    @Test
    void usernameAndEmailAreNormalizedToLowerCase() {
        User saved = userRepository.saveAndFlush(new User("  Ada Lovelace ", "  Ada@Example.COM  ", "h"));

        User loaded = userRepository.findById(saved.getId()).orElseThrow();
        assertThat(loaded.getUsername()).isEqualTo("ada lovelace");
        assertThat(loaded.getEmail()).isEqualTo("ada@example.com");
    }

    @Test
    void duplicateUsernameIsRejectedRegardlessOfCase() {
        userRepository.saveAndFlush(new User("ada", "one@example.com", "h"));

        assertThatThrownBy(() -> userRepository.saveAndFlush(new User("ADA", "two@example.com", "h")))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void duplicateEmailIsRejectedRegardlessOfCase() {
        userRepository.saveAndFlush(new User("bob", "same@example.com", "h"));

        assertThatThrownBy(() -> userRepository.saveAndFlush(new User("carol", "SAME@example.com", "h")))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void usernameCannotBeNull() {
        assertThatThrownBy(() -> userRepository.saveAndFlush(new User(null, "x@example.com", "h")))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void emailCannotBeNull() {
        assertThatThrownBy(() -> userRepository.saveAndFlush(new User("x", null, "h")))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void passwordHashCannotBeNull() {
        assertThatThrownBy(() -> userRepository.saveAndFlush(new User("x", "y@example.com", null)))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void accountStatusDefaultsToActiveAndCanBeChanged() {
        User saved = userRepository.saveAndFlush(new User("grace", "grace@example.com", "h"));
        assertThat(saved.getAccountStatus()).isEqualTo(AccountStatus.ACTIVE);

        saved.setAccountStatus(AccountStatus.LOCKED);
        User reloaded = userRepository.findById(userRepository.saveAndFlush(saved).getId()).orElseThrow();
        assertThat(reloaded.getAccountStatus()).isEqualTo(AccountStatus.LOCKED);
    }

    @Test
    void databaseRejectsUnknownAccountStatus() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, account_status, version, created_at, updated_at) "
                        + "VALUES (gen_random_uuid(), 'invalid', 'invalid@example.com', 'h', 'INVALID', 0, now(), now())"))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void auditingPopulatesAndMaintainsTimestamps() {
        User user = userRepository.saveAndFlush(new User("linus", "linus@example.com", "h"));
        assertThat(user.getCreatedAt()).isNotNull();
        assertThat(user.getUpdatedAt()).isNotNull();

        java.time.Instant originalCreatedAt = user.getCreatedAt();
        user.setAccountStatus(AccountStatus.DISABLED);
        userRepository.saveAndFlush(user);

        User reloaded = userRepository.findById(user.getId()).orElseThrow();
        assertThat(reloaded.getCreatedAt()).isEqualTo(originalCreatedAt);
        assertThat(reloaded.getUpdatedAt()).isAfterOrEqualTo(originalCreatedAt);
    }

    @Test
    void versionStartsAtZeroAndIncrementsOnUpdate() {
        User user = userRepository.saveAndFlush(new User("satoshi", "satoshi@example.com", "h"));
        assertThat(user.getVersion()).isZero();

        user.setAccountStatus(AccountStatus.LOCKED);
        User updated = userRepository.saveAndFlush(user);
        assertThat(updated.getVersion()).isEqualTo(1);
    }

    @Test
    void optimisticLockingConflictIsDetected() {
        User user = userRepository.saveAndFlush(new User("grace", "grace@example.com", "h"));
        UUID id = user.getId();

        entityManager.getEntityManager().createNativeQuery(
                "UPDATE users SET version = version + 100 WHERE id = :id")
            .setParameter("id", id)
            .executeUpdate();

        user.setAccountStatus(AccountStatus.LOCKED);

        assertThatThrownBy(() -> userRepository.saveAndFlush(user))
            .isInstanceOf(OptimisticLockingFailureException.class);
    }
}