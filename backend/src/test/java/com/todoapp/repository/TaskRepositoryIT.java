package com.todoapp.repository;

import com.todoapp.configuration.JpaAuditingConfig;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.entity.User;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
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
class TaskRepositoryIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User newUser(String suffix) {
        return userRepository.saveAndFlush(new User("user" + suffix, suffix + "@example.com", "h"));
    }

    @Test
    void taskCanBePersistedWithDefaults() {
        User user = newUser("1");
        Task task = taskRepository.saveAndFlush(new Task(user, "Write schema migration"));

        Task loaded = taskRepository.findById(task.getId()).orElseThrow();
        assertThat(loaded.getTitle()).isEqualTo("Write schema migration");
        assertThat(loaded.getUser().getId()).isEqualTo(user.getId());
        assertThat(loaded.getStatus()).isEqualTo(TaskStatus.TODO);
        assertThat(loaded.getDescription()).isNull();
        assertThat(loaded.getDueDate()).isNull();
        assertThat(loaded.getCompletedAt()).isNull();
        assertThat(loaded.getCreatedAt()).isNotNull();
        assertThat(loaded.getUpdatedAt()).isNotNull();
    }

    @Test
    void allLifecycleStatusesArePersisted() {
        User user = newUser("2");

        Task todo = taskRepository.saveAndFlush(new Task(user, "todo"));
        Task inProgress = taskRepository.saveAndFlush(new Task(user, "in-progress"));
        inProgress.setStatus(TaskStatus.IN_PROGRESS);
        Task cancelled = taskRepository.saveAndFlush(new Task(user, "cancelled"));
        cancelled.setStatus(TaskStatus.CANCELLED);
        Task completed = taskRepository.saveAndFlush(new Task(user, "completed"));
        completed.setStatus(TaskStatus.COMPLETED);
        completed.setCompletedAt(Instant.now().plusSeconds(60));
        taskRepository.saveAndFlush(completed);

        assertThat(taskRepository.findById(todo.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.TODO);
        assertThat(taskRepository.findById(inProgress.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(taskRepository.findById(cancelled.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.CANCELLED);
        assertThat(taskRepository.findById(completed.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.COMPLETED);
    }

    @Test
    void taskBelongsToUserAndIsQueriedByOwner() {
        User alice = newUser("alice");
        User bob = newUser("bob");

        Task alices = taskRepository.saveAndFlush(new Task(alice, "Alices task"));
        taskRepository.saveAndFlush(new Task(bob, "Bobs task"));

        assertThat(taskRepository.findByUserId(alice.getId()))
            .extracting(Task::getTitle)
            .containsExactly("Alices task");
        assertThat(taskRepository.findByUserId(bob.getId()))
            .extracting(Task::getTitle)
            .containsExactly("Bobs task");

        assertThat(taskRepository.findByIdAndUserId(alices.getId(), alice.getId())).isPresent();
        assertThat(taskRepository.findByIdAndUserId(alices.getId(), bob.getId())).isEmpty();
    }

    @Test
    void titleIsRequired() {
        User user = newUser("3");
        assertThatThrownBy(() -> taskRepository.saveAndFlush(new Task(user, null)))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void descriptionIsOptionalAndPersistedWhenPresent() {
        User user = newUser("4");
        Task without = taskRepository.saveAndFlush(new Task(user, "without"));
        assertThat(without.getDescription()).isNull();

        String text = "very long description ".repeat(80);
        Task with = taskRepository.saveAndFlush(new Task(user, "with", text));
        assertThat(taskRepository.findById(with.getId()).orElseThrow().getDescription()).isEqualTo(text);
    }

    @Test
    void dueDateIsPersisted() {
        User user = newUser("5");
        Task task = taskRepository.saveAndFlush(new Task(user, "dated"));
        task.setDueDate(LocalDate.of(2026, 3, 15));
        taskRepository.saveAndFlush(task);

        assertThat(taskRepository.findById(task.getId()).orElseThrow().getDueDate())
            .isEqualTo(LocalDate.of(2026, 3, 15));
    }

    @Test
    void completedAtIsPersistedWithCompletedStatus() {
        User user = newUser("6");
        Task task = taskRepository.saveAndFlush(new Task(user, "done"));
        Instant completedAt = Instant.now().plusSeconds(60);
        task.setStatus(TaskStatus.COMPLETED);
        task.setCompletedAt(completedAt);
        taskRepository.saveAndFlush(task);

        Task loaded = taskRepository.findById(task.getId()).orElseThrow();
        assertThat(loaded.getStatus()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(loaded.getCompletedAt()).isEqualTo(completedAt);
    }

    @Test
    void completedStatusRequiresCompletedAt() {
        User user = newUser("7");
        Task task = new Task(user, "broken");
        task.setStatus(TaskStatus.COMPLETED);
        assertThatThrownBy(() -> taskRepository.saveAndFlush(task))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void completedAtWithoutCompletedStatusIsRejected() {
        User user = newUser("8");
        Task task = new Task(user, "broken");
        task.setCompletedAt(Instant.now());
        assertThatThrownBy(() -> taskRepository.saveAndFlush(task))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void overDueIsNotAPersistedStatus() {
        User user = newUser("9");
        UUID userId = user.getId();
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO tasks (id, user_id, title, status, version, created_at, updated_at) "
                        + "VALUES (gen_random_uuid(), ?, 'overdue', 'OVERDUE', 0, now(), now())", userId))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void taskMustBelongToExistingUser() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO tasks (id, user_id, title, version, created_at, updated_at) "
                        + "VALUES (gen_random_uuid(), ?, 'ghost', 0, now(), now())",
                UUID.randomUUID()))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void deletingUserCascadesToTasks() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update("INSERT INTO users (id, username, email, password_hash, version, created_at, updated_at) "
                + "VALUES (?, 'cascade-task', 'cascade-task@example.com', 'h', 0, now(), now())", userId);
        jdbcTemplate.update("INSERT INTO tasks (id, user_id, title, version, created_at, updated_at) "
                + "VALUES (gen_random_uuid(), ?, 'first task', 0, now(), now())", userId);

        jdbcTemplate.update("DELETE FROM users WHERE id = ?", userId);

        Integer remaining = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM tasks WHERE user_id = ?", Integer.class, userId);
        assertThat(remaining).isZero();
    }
}