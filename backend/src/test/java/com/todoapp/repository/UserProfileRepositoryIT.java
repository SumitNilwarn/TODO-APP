package com.todoapp.repository;

import com.todoapp.configuration.JpaAuditingConfig;
import com.todoapp.entity.User;
import com.todoapp.entity.UserProfile;
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
class UserProfileRepositoryIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserProfileRepository userProfileRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void profileCanBePersistedAndBelongsToItsUser() {
        User user = userRepository.saveAndFlush(new User("ada", "ada@example.com", "h"));
        UserProfile profile = userProfileRepository.saveAndFlush(
                new UserProfile(user, "Ada", "Lovelace", "Ada L.", "Europe/London", "/img/ada.png"));

        UserProfile loaded = userProfileRepository.findById(profile.getId()).orElseThrow();
        assertThat(loaded.getUser().getId()).isEqualTo(user.getId());
        assertThat(loaded.getFirstName()).isEqualTo("Ada");
        assertThat(loaded.getLastName()).isEqualTo("Lovelace");
        assertThat(loaded.getDisplayName()).isEqualTo("Ada L.");
        assertThat(loaded.getTimezone()).isEqualTo("Europe/London");
        assertThat(loaded.getProfileImageUrl()).isEqualTo("/img/ada.png");
        assertThat(loaded.getCreatedAt()).isNotNull();
        assertThat(loaded.getUpdatedAt()).isNotNull();
    }

    @Test
    void profileIsFoundByUserId() {
        User user = userRepository.saveAndFlush(new User("grace", "grace@example.com", "h"));
        userProfileRepository.saveAndFlush(new UserProfile(user, "Grace", null, "Grace H.", null, null));

        assertThat(userProfileRepository.findByUserId(user.getId())).get()
            .extracting(UserProfile::getFirstName)
            .isEqualTo("Grace");
    }

    @Test
    void secondProfileForSameUserIsRejected() {
        User user = userRepository.saveAndFlush(new User("linus", "linus@example.com", "h"));
        userProfileRepository.saveAndFlush(new UserProfile(user, "Linus", "T.", "Linus", null, null));

        assertThatThrownBy(() -> userProfileRepository.saveAndFlush(
                new UserProfile(user, "Other", "Profile", "Other", null, null)))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void profileRequiresExistingUser() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO user_profiles (id, user_id, first_name, version, created_at, updated_at) "
                        + "VALUES (gen_random_uuid(), ?, 'ghost', 0, now(), now())",
                UUID.randomUUID()))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void deletingUserCascadesToProfile() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update("INSERT INTO users (id, username, email, password_hash, version, created_at, updated_at) "
                + "VALUES (?, 'cascade', 'cascade@example.com', 'h', 0, now(), now())", userId);
        jdbcTemplate.update("INSERT INTO user_profiles (id, user_id, first_name, version, created_at, updated_at) "
                + "VALUES (gen_random_uuid(), ?, 'first', 0, now(), now())", userId);

        jdbcTemplate.update("DELETE FROM users WHERE id = ?", userId);

        Integer remaining = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM user_profiles WHERE user_id = ?", Integer.class, userId);
        assertThat(remaining).isZero();
    }

    @Test
    void optimisticLockingConflictIsDetected() {
        User user = userRepository.saveAndFlush(new User("locky", "locky@example.com", "h"));
        UserProfile profile = userProfileRepository.saveAndFlush(
                new UserProfile(user, "Lock", "Y", "Lock Y", null, null));
        UUID profileId = profile.getId();

        entityManager.getEntityManager().createNativeQuery(
                "UPDATE user_profiles SET version = version + 100 WHERE id = :id")
                .setParameter("id", profileId)
                .executeUpdate();

        profile.setFirstName("Changed");

        assertThatThrownBy(() -> userProfileRepository.saveAndFlush(profile))
                .isInstanceOf(OptimisticLockingFailureException.class);
    }
}