package com.todoapp.repository;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verifies the Flyway schema against a clean PostgreSQL database: migrations
 * apply, the tables/indexes/constraints described in the design exist, and the
 * Hibernate {@code validate} mapping check passes (proven by the context
 * loading successfully against that schema).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Testcontainers
class DatabaseSchemaIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private Environment environment;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void migrationsInitializeACleanDatabase() {
        List<String> tables = jdbcTemplate.queryForList(
                "SELECT tablename FROM pg_catalog.pg_tables "
                        + "WHERE schemaname = 'public' "
                        + "  AND tablename IN ('users', 'user_profiles', 'tasks', 'refresh_tokens') "
                        + "ORDER BY tablename",
                String.class);
        assertThat(tables).containsExactly("refresh_tokens", "tasks", "user_profiles", "users");
    }

    @Test
    void flywayHistoryRecordsAllAppliedMigrations() {
        List<String> versions = jdbcTemplate.queryForList(
                "SELECT version FROM flyway_schema_history ORDER BY installed_rank",
                String.class);
        assertThat(versions).containsExactly("1", "2", "3", "4");

        Integer failed = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE success = false", Integer.class);
        assertThat(failed).isZero();
    }

    @Test
    void plannedIndexesExist() {
        List<String> indexes = jdbcTemplate.queryForList(
                "SELECT indexname FROM pg_catalog.pg_indexes "
                        + "WHERE schemaname = 'public' AND indexname IN "
                        + "('uk_users_username', 'uk_users_email', 'uk_user_profiles_user', "
                        + " 'idx_tasks_user_status', 'idx_tasks_user_due_date', "
                        + " 'idx_refresh_tokens_user_id', 'idx_refresh_tokens_expires_at') ORDER BY indexname",
                String.class);
        assertThat(indexes).containsExactlyInAnyOrder(
                "uk_users_username", "uk_users_email",
                "uk_user_profiles_user", "idx_tasks_user_status", "idx_tasks_user_due_date",
                "idx_refresh_tokens_user_id", "idx_refresh_tokens_expires_at");
    }

    @Test
    void plannedConstraintsExist() {
        List<String> constraints = jdbcTemplate.queryForList(
                "SELECT conname FROM pg_catalog.pg_constraint WHERE conname IN "
                        + "('fk_tasks_user', 'fk_user_profiles_user', "
                        + " 'fk_refresh_tokens_user', "
                        + " 'ck_tasks_status', 'ck_tasks_completed_at_status', "
                        + " 'ck_users_account_status', 'ck_users_username_normalized', "
                        + " 'ck_user_profiles_timestamps', "
                        + " 'ck_refresh_tokens_revoked_at_after_created') ORDER BY conname",
                String.class);
        assertThat(constraints).contains(
                "fk_tasks_user", "fk_user_profiles_user", "fk_refresh_tokens_user",
                "ck_tasks_status", "ck_tasks_completed_at_status",
                "ck_users_account_status", "ck_users_username_normalized",
                "ck_user_profiles_timestamps", "ck_refresh_tokens_revoked_at_after_created");
    }

    @Test
    void hibernateValidationIsConfiguredAndPassesAgainstSchema() {
        assertThat(environment.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
        assertThat(environment.getProperty("spring.flyway.enabled")).isEqualTo("true");
    }

    @Test
    void postgresVersionIs16() {
        String version = jdbcTemplate.queryForObject("SHOW server_version", String.class);
        assertThat(version).startsWith("16.");
    }
}