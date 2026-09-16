package com.todoapp.service;

import com.todoapp.dto.FieldViolation;
import com.todoapp.dto.task.CreateTaskRequest;
import com.todoapp.dto.task.TaskListQuery;
import com.todoapp.dto.task.TaskPageResponse;
import com.todoapp.dto.task.TaskPatchRequest;
import com.todoapp.dto.task.TaskPatchValue;
import com.todoapp.dto.task.TaskResponse;
import com.todoapp.dto.task.UpdateTaskRequest;
import com.todoapp.dto.task.UpdateTaskStatusRequest;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.entity.User;
import com.todoapp.exception.FieldValidationException;
import com.todoapp.exception.InvalidTaskTransitionException;
import com.todoapp.exception.TaskNotFoundException;
import com.todoapp.repository.TaskRepository;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskServiceTest {

    private static final UUID USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID TASK_ID = UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final AuthenticatedUser PRINCIPAL = new AuthenticatedUser(USER_ID, "ada");
    private static final Instant FIXED_INSTANT = Instant.parse("2026-07-15T10:00:00Z");
    private static final Clock CLOCK = Clock.fixed(FIXED_INSTANT, ZoneOffset.UTC);
    private static final LocalDate TODAY = LocalDate.of(2026, 7, 15);

    @Mock
    private TaskRepository taskRepository;
    @Mock
    private UserRepository userRepository;

    private TaskService taskService;

    @BeforeEach
    void setUp() {
        taskService = new TaskService(taskRepository, userRepository, CLOCK, 100);
    }

    private static User user() {
        return new User("ada", "ada@example.com", "hash");
    }

    private static Task task(String title, TaskStatus status, LocalDate dueDate, Instant completedAt) {
        Task task = new Task(user(), title);
        task.setStatus(status);
        task.setDueDate(dueDate);
        task.setCompletedAt(completedAt);
        return task;
    }

    private static TaskPatchRequest patch(TaskPatchValue title, TaskPatchValue description,
                                          TaskPatchValue status, TaskPatchValue dueDate) {
        TaskPatchRequest request = new TaskPatchRequest();
        request.setTitle(title);
        request.setDescription(description);
        request.setStatus(status);
        request.setDueDate(dueDate);
        return request;
    }

    // ---------------------------------------------------------------- create

    @Test
    void createTaskDefaultsToTodo() {
        User user = user();
        when(userRepository.getReferenceById(USER_ID)).thenReturn(user);
        when(taskRepository.saveAndFlush(any(Task.class))).thenAnswer(i -> i.getArgument(0));

        TaskResponse response = taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("  Write schema  ", null, null, null));

        assertThat(response.title()).isEqualTo("Write schema");
        assertThat(response.status()).isEqualTo(TaskStatus.TODO);
        assertThat(response.description()).isNull();
        assertThat(response.dueDate()).isNull();
        assertThat(response.completedAt()).isNull();
        assertThat(response.overdue()).isFalse();
        verify(userRepository).getReferenceById(USER_ID);
    }

    @Test
    void createTaskWithFullValidFields() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(user());
        when(taskRepository.saveAndFlush(any(Task.class))).thenAnswer(i -> i.getArgument(0));

        TaskResponse response = taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("Ship", "  Release v2  ", TaskStatus.IN_PROGRESS,
                        LocalDate.of(2026, 7, 20)));

        assertThat(response.title()).isEqualTo("Ship");
        assertThat(response.description()).isEqualTo("Release v2");
        assertThat(response.status()).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(response.dueDate()).isEqualTo(LocalDate.of(2026, 7, 20));
        assertThat(response.completedAt()).isNull();
    }

    @Test
    void createTaskWithCompletedStatusSetsCompletedAtFromServerClock() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(user());
        when(taskRepository.saveAndFlush(any(Task.class))).thenAnswer(i -> i.getArgument(0));

        TaskResponse response = taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("Done already", null, TaskStatus.COMPLETED, null));

        assertThat(response.status()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(response.completedAt()).isEqualTo(FIXED_INSTANT);
    }

    @Test
    void createTaskRejectsBlankTitle() {
        assertThatThrownBy(() -> taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("   ", null, null, null)))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("title"));
        verify(taskRepository, never()).saveAndFlush(any());
    }

    @Test
    void createTaskRejectsBlankDescription() {
        assertThatThrownBy(() -> taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("Title", "   ", null, null)))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("description"));
    }

    @Test
    void createTaskRejectsOverLengthTitle() {
        assertThatThrownBy(() -> taskService.createTask(PRINCIPAL,
                new CreateTaskRequest("x".repeat(Task.TITLE_MAX_LENGTH + 1), null, null, null)))
                .isInstanceOf(FieldValidationException.class);
    }

    // ---------------------------------------------------------------- get

    @Test
    void getTaskReturnsOwnedTask() {
        Task task = task("Mine", TaskStatus.TODO, TODAY.minusDays(2), null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        TaskResponse response = taskService.getTask(PRINCIPAL, TASK_ID);

        assertThat(response.id()).isEqualTo(task.getId());
        assertThat(response.title()).isEqualTo("Mine");
        assertThat(response.overdue()).isTrue();
    }

    @Test
    void getTaskThrowsNotFoundWhenMissingOrForeign() {
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> taskService.getTask(PRINCIPAL, TASK_ID))
                .isInstanceOf(TaskNotFoundException.class);
    }

    // ---------------------------------------------------------------- list

    @Test
    void listTasksDefaultsToFirstPageOfTwentySortedByCreatedAtDescending() {
        when(taskRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));

        TaskPageResponse response = taskService.listTasks(PRINCIPAL,
                new TaskListQuery(null, null, null, null, null, null, null, null, null));

        assertThat(response.page()).isZero();
        assertThat(response.size()).isEqualTo(20);
        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(taskRepository).findAll(any(Specification.class), captor.capture());
        assertThat(captor.getValue().getPageNumber()).isZero();
        assertThat(captor.getValue().getPageSize()).isEqualTo(20);
        assertThat(captor.getValue().getSort().stream().map(Sort.Order::getProperty))
                .containsExactly("createdAt", "id");
        assertThat(captor.getValue().getSort().getOrderFor("createdAt").getDirection())
                .isEqualTo(Sort.Direction.DESC);
        assertThat(captor.getValue().getSort().getOrderFor("id").getDirection())
                .isEqualTo(Sort.Direction.ASC);
    }

    @Test
    void listTasksAppliesRequestedSortAndDirection() {
        when(taskRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));

        taskService.listTasks(PRINCIPAL, new TaskListQuery(
                "0", "10", "title", "ASC", null, null, null, null, null));

        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(taskRepository).findAll(any(Specification.class), captor.capture());
        assertThat(captor.getValue().getSort().stream().map(Sort.Order::getProperty))
                .containsExactly("title", "id");
        assertThat(captor.getValue().getSort().getOrderFor("title").getDirection())
                .isEqualTo(Sort.Direction.ASC);
        assertThat(captor.getValue().getSort().getOrderFor("id").getDirection())
                .isEqualTo(Sort.Direction.ASC);
    }

    @Test
    void listTasksMapsPageIntoPaginatedResponse() {
        Task overdue = task("Alpha", TaskStatus.TODO, TODAY.minusDays(1), null);
        Task completed = task("Beta", TaskStatus.COMPLETED, TODAY.minusDays(5), FIXED_INSTANT);
        when(taskRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(overdue, completed), PageRequest.of(1, 2), 4));

        TaskPageResponse response = taskService.listTasks(PRINCIPAL,
                new TaskListQuery("1", "2", null, null, null, null, null, null, null));

        assertThat(response.content()).extracting(TaskResponse::title)
                .containsExactly("Alpha", "Beta");
        assertThat(response.content()).extracting(TaskResponse::overdue)
                .containsExactly(true, false);
        assertThat(response.page()).isEqualTo(1);
        assertThat(response.size()).isEqualTo(2);
        assertThat(response.totalElements()).isEqualTo(4);
        assertThat(response.totalPages()).isEqualTo(2);
        assertThat(response.first()).isFalse();
        assertThat(response.last()).isTrue();
    }

    @Test
    void listTasksRejectsNegativePage() {
        assertListValidationError("page", "-1", "must be greater than or equal to 0");
    }

    @Test
    void listTasksRejectsNonNumericPage() {
        assertListValidationError("page", "abc", "must be an integer");
    }

    @Test
    void listTasksRejectsZeroSize() {
        assertListValidationError("size", "0", "must be at least 1");
    }

    @Test
    void listTasksRejectsOverMaxPageSize() {
        assertListValidationError("size", "101", "must be at most 100");
    }

    @Test
    void listTasksRejectsUnsupportedSortField() {
        assertListValidationError("sort", "userId",
                "must be one of createdAt, updatedAt, dueDate, title, status");
        assertListValidationError("sort", "overdue",
                "must be one of createdAt, updatedAt, dueDate, title, status");
    }

    @Test
    void listTasksRejectsInvalidDirection() {
        assertListValidationError("direction", "UP", "must be ASC or DESC");
    }

    @Test
    void listTasksRejectsUnknownStatus() {
        assertListValidationError("status", "WIP",
                "must be one of TODO, IN_PROGRESS, COMPLETED, CANCELLED");
    }

    @Test
    void listTasksRejectsOverdueAsStatus() {
        assertListValidationError("status", "OVERDUE",
                "OVERDUE is a derived flag, not a status; use overdue=true|false");
    }

    @Test
    void listTasksRejectsMalformedDate() {
        assertListValidationError("dueDateFrom", "01-08-2026",
                "must be a valid ISO-8601 date (yyyy-MM-dd)");
        assertListValidationError("dueDateTo", "not-a-date",
                "must be a valid ISO-8601 date (yyyy-MM-dd)");
    }

    @Test
    void listTasksRejectsReversedDateRange() {
        assertListValidationError("dueDateFrom", "2026-08-02",
                "must not be after dueDateTo", "2026-08-01");
    }

    @Test
    void listTasksRejectsInvalidOverdueValue() {
        assertListValidationError("overdue", "yes", "must be true or false");
    }

    @Test
    void listTasksRejectsOversizedSearch() {
        assertListValidationError("search", "a".repeat(201), "must be at most 200 characters");
    }

    @Test
    void blankSearchAndBlankFiltersActAsAbsent() {
        when(taskRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));
        String blank = "   ";

        TaskPageResponse response = taskService.listTasks(PRINCIPAL,
                new TaskListQuery(blank, blank, blank, blank, blank, blank, blank, blank, blank));

        assertThat(response.totalElements()).isZero();
        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(taskRepository).findAll(any(Specification.class), captor.capture());
        assertThat(captor.getValue().getPageNumber()).isZero();
        assertThat(captor.getValue().getSort().getOrderFor("createdAt").getDirection())
                .isEqualTo(Sort.Direction.DESC);
    }

    @Test
    void overdueFilterValuesAreAccepted() {
        when(taskRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));

        taskService.listTasks(PRINCIPAL,
                new TaskListQuery(null, null, null, null, null, null, null, "true", null));
        taskService.listTasks(PRINCIPAL,
                new TaskListQuery(null, null, null, null, null, null, null, "FALSE", null));

        verify(taskRepository, org.mockito.Mockito.times(2))
                .findAll(any(Specification.class), any(Pageable.class));
    }

    private void assertListValidationError(String field, String value, String message) {
        assertListValidationError(field, value, message, null);
    }

    private void assertListValidationError(String field, String value, String message, String dueDateTo) {
        TaskListQuery query = new TaskListQuery(
                field.equals("page") ? value : null,
                field.equals("size") ? value : null,
                field.equals("sort") ? value : null,
                field.equals("direction") ? value : null,
                field.equals("status") ? value : null,
                field.equals("dueDateFrom") ? value : null,
                field.equals("dueDateTo") ? value : dueDateTo,
                field.equals("overdue") ? value : null,
                field.equals("search") ? value : null);

        assertThatThrownBy(() -> taskService.listTasks(PRINCIPAL, query))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> {
                    List<FieldViolation> violations = ((FieldValidationException) ex).getViolations();
                    assertThat(violations).extracting(FieldViolation::field).contains(field);
                    assertThat(violations)
                            .filteredOn(violation -> violation.field().equals(field))
                            .extracting(FieldViolation::message)
                            .anyMatch(text -> text.contains(message));
                });
        verify(taskRepository, never()).findAll(any(Specification.class), any(Pageable.class));
    }

    @Test
    void listTasksRejectedInvalidCombinationsProduceAllViolations() {
        TaskListQuery query = new TaskListQuery(
                "-1", "300", "overdue", "UP", "WIP", "2026-08-02", "2026-08-01", "yes",
                "a".repeat(201));

        assertThatThrownBy(() -> taskService.listTasks(PRINCIPAL, query))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .contains("page", "size", "sort", "direction", "status",
                                "dueDateFrom", "overdue", "search"));
    }

    // ---------------------------------------------------------------- update

    @Test
    void updateTaskReplacesAllEditableFields() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("new title", null, TaskStatus.IN_PROGRESS, TODAY));

        assertThat(task.getTitle()).isEqualTo("new title");
        assertThat(task.getDescription()).isNull();
        assertThat(task.getStatus()).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(task.getDueDate()).isEqualTo(TODAY);
        assertThat(response.completedAt()).isNull();
    }

    @Test
    void updateTaskCannotReopenCompletedTask() {
        Task task = task("done", TaskStatus.COMPLETED, null, FIXED_INSTANT);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("reopen", null, TaskStatus.TODO, null)))
                .isInstanceOf(InvalidTaskTransitionException.class);
        verify(taskRepository, never()).saveAndFlush(any());
    }

    @Test
    void updateTaskToCompletedSetsCompletedAtFromClock() {
        Task task = task("in progress", TaskStatus.IN_PROGRESS, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("done", null, TaskStatus.COMPLETED, null));

        assertThat(task.getCompletedAt()).isEqualTo(FIXED_INSTANT);
        assertThat(response.completedAt()).isEqualTo(FIXED_INSTANT);
    }

    @Test
    void updateTaskKeepingCompletedStatusPreservesCompletedAt() {
        Instant completedAt = FIXED_INSTANT.minusSeconds(3600);
        Task task = task("done", TaskStatus.COMPLETED, null, completedAt);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("renamed", null, TaskStatus.COMPLETED, null));

        assertThat(response.completedAt()).isEqualTo(completedAt);
    }

    @Test
    void updateTaskValidatesFieldsBeforeMutating() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("   ", null, TaskStatus.IN_PROGRESS, null)))
                .isInstanceOf(FieldValidationException.class);
        assertThat(task.getTitle()).isEqualTo("old");
        verify(taskRepository, never()).saveAndFlush(any());
    }

    // ---------------------------------------------------------------- patch

    @Test
    void patchTaskAppliesOnlyProvidedFields() {
        Task task = task("old", TaskStatus.TODO, TODAY.plusDays(3), null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.of("  Grace  "), TaskPatchValue.omitted(),
                        TaskPatchValue.omitted(), TaskPatchValue.omitted()));

        assertThat(task.getTitle()).isEqualTo("Grace");
        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);
        assertThat(task.getDueDate()).isEqualTo(TODAY.plusDays(3));
        assertThat(response.title()).isEqualTo("Grace");
    }

    @Test
    void patchTaskExplicitNullClearsOptionalFields() {
        Task task = task("old", TaskStatus.TODO, TODAY, null);
        task.setDescription("desc");
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.ofNull(),
                        TaskPatchValue.omitted(), TaskPatchValue.ofNull()));

        assertThat(task.getDescription()).isNull();
        assertThat(task.getDueDate()).isNull();
        assertThat(task.getTitle()).isEqualTo("old");
    }

    @Test
    void patchTaskSilentlyNoopOnEmptyBody() {
        Task task = task("old", TaskStatus.TODO, TODAY, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        taskService.patchTask(PRINCIPAL, TASK_ID, patch(
                TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                TaskPatchValue.omitted(), TaskPatchValue.omitted()));

        assertThat(task.getTitle()).isEqualTo("old");
        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);
    }

    @Test
    void patchTaskRejectsNullTitle() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.ofNull(), TaskPatchValue.omitted(),
                        TaskPatchValue.omitted(), TaskPatchValue.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("title"));
        verify(taskRepository, never()).saveAndFlush(any());
    }

    @Test
    void patchTaskRejectsInvalidStatusValue() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                        TaskPatchValue.of("BACKLOG"), TaskPatchValue.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("status"));
    }

    @Test
    void patchTaskRejectsOverdueAsAnInputStatus() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                        TaskPatchValue.of("OVERDUE"), TaskPatchValue.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("status"));
    }

    @Test
    void patchTaskRejectsMalformedDueDate() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                        TaskPatchValue.omitted(), TaskPatchValue.of("2026-13-45"))))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("dueDate"));
    }

    @Test
    void patchTaskAppliesValidStatusTransitionAndReconcilesCompletedAt() {
        Task task = task("in progress", TaskStatus.IN_PROGRESS, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                        TaskPatchValue.of("COMPLETED"), TaskPatchValue.omitted()));

        assertThat(response.status()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(response.completedAt()).isEqualTo(FIXED_INSTANT);
    }

    @Test
    void patchTaskRejectsInvalidTransitionOnCompletedTask() {
        Task task = task("done", TaskStatus.COMPLETED, null, FIXED_INSTANT);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.patchTask(PRINCIPAL, TASK_ID,
                patch(TaskPatchValue.omitted(), TaskPatchValue.omitted(),
                        TaskPatchValue.of("IN_PROGRESS"), TaskPatchValue.omitted())))
                .isInstanceOf(InvalidTaskTransitionException.class);
    }

    // ---------------------------------------------------------------- status

    @Test
    void changeStatusAllowsValidForwardTransition() {
        Task task = task("in progress", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.changeStatus(PRINCIPAL, TASK_ID,
                new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS));

        assertThat(response.status()).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(response.completedAt()).isNull();
    }

    @Test
    void changeStatusToCompletedSetsCompletedAtFromServerClock() {
        Task task = task("running", TaskStatus.IN_PROGRESS, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.changeStatus(PRINCIPAL, TASK_ID,
                new UpdateTaskStatusRequest(TaskStatus.COMPLETED));

        assertThat(response.status()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(response.completedAt()).isEqualTo(FIXED_INSTANT);
    }

    @Test
    void changeStatusToNonCompletedStatusClearsStaleCompletedAt() {
        Task task = task("running", TaskStatus.TODO, null, FIXED_INSTANT);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.changeStatus(PRINCIPAL, TASK_ID,
                new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS));

        assertThat(response.status()).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(task.getCompletedAt()).isNull();
    }

    @Test
    void changeStatusRejectsInvalidTransition() {
        Task task = task("cancelled", TaskStatus.CANCELLED, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.changeStatus(PRINCIPAL, TASK_ID,
                new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS)))
                .isInstanceOf(InvalidTaskTransitionException.class);
        verify(taskRepository, never()).saveAndFlush(any());
    }

    @Test
    void changeStatusSameStatusIsIdempotent() {
        Task task = task("todo", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.changeStatus(PRINCIPAL, TASK_ID,
                new UpdateTaskStatusRequest(TaskStatus.TODO));

        assertThat(response.status()).isEqualTo(TaskStatus.TODO);
    }

    // ---------------------------------------------------------------- complete

    @Test
    void completeTaskSetsCompletedStateFromServerClock() {
        Task task = task("running", TaskStatus.IN_PROGRESS, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.completeTask(PRINCIPAL, TASK_ID);

        assertThat(response.status()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(response.completedAt()).isEqualTo(FIXED_INSTANT);
        assertThat(response.overdue()).isFalse();
    }

    @Test
    void completeTaskIsIdempotentAndPreservesOriginalCompletedAt() {
        Instant completedAt = FIXED_INSTANT.minusSeconds(7200);
        Task task = task("done", TaskStatus.COMPLETED, null, completedAt);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.completeTask(PRINCIPAL, TASK_ID);

        assertThat(response.completedAt()).isEqualTo(completedAt);
    }

    @Test
    void completeTaskRejectedForCancelledTask() {
        Task task = task("cancelled", TaskStatus.CANCELLED, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.completeTask(PRINCIPAL, TASK_ID))
                .isInstanceOf(InvalidTaskTransitionException.class);
    }

    // ---------------------------------------------------------------- cancel

    @Test
    void cancelTaskClearsCompletedAt() {
        Task task = task("done", TaskStatus.IN_PROGRESS, null, FIXED_INSTANT);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.cancelTask(PRINCIPAL, TASK_ID);

        assertThat(response.status()).isEqualTo(TaskStatus.CANCELLED);
        assertThat(task.getCompletedAt()).isNull();
    }

    @Test
    void cancelTaskRejectedForCompletedTask() {
        Task task = task("done", TaskStatus.COMPLETED, null, FIXED_INSTANT);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.cancelTask(PRINCIPAL, TASK_ID))
                .isInstanceOf(InvalidTaskTransitionException.class);
    }

    @Test
    void cancelTaskIsIdempotent() {
        Task task = task("cancelled", TaskStatus.CANCELLED, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task)).thenReturn(task);

        TaskResponse response = taskService.cancelTask(PRINCIPAL, TASK_ID);

        assertThat(response.status()).isEqualTo(TaskStatus.CANCELLED);
    }

    // ---------------------------------------------------------------- delete

    @Test
    void deleteTaskDeletesOnlyOwnedTask() {
        Task task = task("mine", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        taskService.deleteTask(PRINCIPAL, TASK_ID);

        verify(taskRepository).delete((Task) task);
        verify(taskRepository).flush();
    }

    @Test
    void deleteTaskThrowsNotFoundForForeignOrMissingTask() {
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> taskService.deleteTask(PRINCIPAL, TASK_ID))
                .isInstanceOf(TaskNotFoundException.class);
        verify(taskRepository, never()).delete(any(Task.class));
    }

    // ---------------------------------------------------------------- overdue

    @Test
    void overdueIsDerivedCorrectlyForAllStatusesAndDates() {
        assertOverdue(TaskStatus.TODO, TODAY.minusDays(1), true);
        assertOverdue(TaskStatus.IN_PROGRESS, TODAY.minusDays(1), true);
        assertOverdue(TaskStatus.TODO, TODAY, false);
        assertOverdue(TaskStatus.TODO, TODAY.plusDays(1), false);
        assertOverdue(TaskStatus.COMPLETED, TODAY.minusDays(5), false);
        assertOverdue(TaskStatus.CANCELLED, TODAY.minusDays(5), false);
        assertOverdue(TaskStatus.TODO, null, false);
    }

    private void assertOverdue(TaskStatus status, LocalDate dueDate, boolean expected) {
        Task task = task("t", status, dueDate, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));

        assertThat(taskService.getTask(PRINCIPAL, TASK_ID).overdue())
                .as("overdue for %s due %s", status, dueDate)
                .isEqualTo(expected);
    }

    // ---------------------------------------------------------------- lock

    @Test
    void updatePropagatesOptimisticLockConflict() {
        Task task = task("old", TaskStatus.TODO, null, null);
        when(taskRepository.findByIdAndUserId(TASK_ID, USER_ID)).thenReturn(Optional.of(task));
        when(taskRepository.saveAndFlush(task))
                .thenThrow(new ObjectOptimisticLockingFailureException(Task.class, TASK_ID));

        assertThatThrownBy(() -> taskService.updateTask(PRINCIPAL, TASK_ID,
                new UpdateTaskRequest("new", null, TaskStatus.IN_PROGRESS, null)))
                .isInstanceOf(ObjectOptimisticLockingFailureException.class);
    }
}