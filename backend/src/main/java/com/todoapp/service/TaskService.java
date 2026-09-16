package com.todoapp.service;

import com.todoapp.dto.FieldViolation;
import com.todoapp.dto.task.CreateTaskRequest;
import com.todoapp.dto.task.TaskListQuery;
import com.todoapp.dto.task.TaskPageResponse;
import com.todoapp.dto.task.TaskPatchRequest;
import com.todoapp.dto.task.TaskQueryFilters;
import com.todoapp.dto.task.TaskResponse;
import com.todoapp.dto.task.UpdateTaskRequest;
import com.todoapp.dto.task.UpdateTaskStatusRequest;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.exception.FieldValidationException;
import com.todoapp.exception.InvalidTaskTransitionException;
import com.todoapp.exception.TaskNotFoundException;
import com.todoapp.repository.TaskRepository;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Authenticated task management.
 *
 * <p>User identity always comes from the {@link AuthenticatedUser} principal
 * established by the JWT filter; no client-supplied {@code userId} is ever
 * used. Ownership is enforced by querying the repository with both the task id
 * and {@code principal.userId()}, so a task belonging to another user is
 * indistinguishable from a missing task (404 {@code TASK_NOT_FOUND}) — IDOR is
 * impossible by construction, mirroring {@link ProfileService}.</p>
 *
 * <p>Lifecycle rules (enforced on POST/PUT/PATCH/status/complete/cancel):
 * every task starts as {@code TODO}; {@code TODO}/{@code IN_PROGRESS} move
 * forward freely; {@code COMPLETED} and {@code CANCELLED} are terminal (a
 * same-status request is an idempotent no-op). Whenever a task becomes
 * {@code COMPLETED}, {@code completedAt} is set from the injected
 * {@link Clock} — never from the client — and is cleared for any other status.
 * {@code OVERDUE} is derived at response time and never persisted.</p>
 *
 * <p>Optimistic locking is preserved via {@code @Version}: stale concurrent
 * writes surface as {@link org.springframework.dao.OptimisticLockingFailureException},
 * translated by the exception handler into a 409 {@code OPTIMISTIC_LOCK_CONFLICT}.</p>
 */
@Service
public class TaskService {

    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;
    private static final String DEFAULT_SORT_FIELD = "createdAt";
    private static final Sort.Direction DEFAULT_DIRECTION = Sort.Direction.DESC;
    private static final List<String> SORTABLE_FIELDS =
            List.of("createdAt", "updatedAt", "dueDate", "title", "status");
    private static final int MAX_SEARCH_LENGTH = 200;

    private final TaskRepository taskRepository;
    private final UserRepository userRepository;
    private final Clock clock;
    private final int maxPageSize;

    public TaskService(TaskRepository taskRepository, UserRepository userRepository, Clock clock,
                       @Value("${app.tasks.max-page-size:100}") int maxPageSize) {
        this.taskRepository = taskRepository;
        this.userRepository = userRepository;
        this.clock = clock;
        this.maxPageSize = maxPageSize;
    }

    private static final Map<TaskStatus, Set<TaskStatus>> ALLOWED_TRANSITIONS = Map.of(
            TaskStatus.TODO, EnumSet.of(TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED),
            TaskStatus.IN_PROGRESS, EnumSet.of(TaskStatus.COMPLETED, TaskStatus.CANCELLED),
            TaskStatus.COMPLETED, EnumSet.noneOf(TaskStatus.class),
            TaskStatus.CANCELLED, EnumSet.noneOf(TaskStatus.class));

    @Transactional(readOnly = true)
    public TaskPageResponse listTasks(AuthenticatedUser principal, TaskListQuery query) {
        UUID userId = principal.userId();
        TaskQueryFilters filters = parseQuery(query);
        LocalDate today = LocalDate.now(clock);
        Sort sort = Sort.by(new Sort.Order(filters.direction(), filters.sortField()),
                new Sort.Order(Sort.Direction.ASC, "id"));
        Pageable pageable = PageRequest.of(filters.page(), filters.size(), sort);
        Page<Task> page = taskRepository.findAll(
                TaskSpecifications.forUserAndFilters(userId, filters, today), pageable);
        List<TaskResponse> content = page.getContent().stream().map(this::toResponse).toList();
        return new TaskPageResponse(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages(), page.isFirst(), page.isLast());
    }

    @Transactional(readOnly = true)
    public TaskResponse getTask(AuthenticatedUser principal, UUID taskId) {
        return toResponse(ownedTask(principal.userId(), taskId));
    }

    @Transactional
    public TaskResponse createTask(AuthenticatedUser principal, CreateTaskRequest request) {
        UUID userId = principal.userId();
        List<FieldViolation> violations = new ArrayList<>();
        String title = validateTitle(request.title(), "title", violations);
        String description = validateDescription(request.description(), violations);
        if (!violations.isEmpty()) {
            throw new FieldValidationException(violations);
        }
        TaskStatus targetStatus = request.status() == null ? TaskStatus.TODO : request.status();
        Task task = new Task(userRepository.getReferenceById(userId), title);
        task.setDescription(description);
        task.setDueDate(request.dueDate());
        task.setStatus(targetStatus);
        applyCompletionTimestamp(task, targetStatus);
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public TaskResponse updateTask(AuthenticatedUser principal, UUID taskId, UpdateTaskRequest request) {
        Task task = ownedTask(principal.userId(), taskId);
        TaskStatus from = task.getStatus();
        requireTransition(from, request.status());
        List<FieldViolation> violations = new ArrayList<>();
        String title = validateTitle(request.title(), "title", violations);
        String description = validateDescription(request.description(), violations);
        if (!violations.isEmpty()) {
            throw new FieldValidationException(violations);
        }
        task.setTitle(title);
        task.setDescription(description);
        task.setDueDate(request.dueDate());
        task.setStatus(request.status());
        applyCompletionTimestamp(task, from);
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public TaskResponse patchTask(AuthenticatedUser principal, UUID taskId, TaskPatchRequest request) {
        Task task = ownedTask(principal.userId(), taskId);
        List<FieldViolation> violations = new ArrayList<>();

        String title = null;
        boolean titleProvided = false;
        if (request.title().isProvided()) {
            titleProvided = true;
            if (request.title().getText() == null) {
                violations.add(new FieldViolation("title", "must not be null"));
            } else {
                title = validateTitle(request.title().getText(), "title", violations);
            }
        }

        String description = null;
        boolean descriptionProvided = false;
        if (request.description().isProvided()) {
            descriptionProvided = true;
            String raw = request.description().getText();
            if (raw != null) {
                description = validateDescription(raw, violations);
            }
        }

        TaskStatus newStatus = null;
        boolean statusProvided = false;
        if (request.status().isProvided()) {
            statusProvided = true;
            String raw = request.status().getText();
            if (raw == null) {
                violations.add(new FieldViolation("status", "must not be null"));
            } else {
                newStatus = parseStatus(raw, violations);
            }
        }

        LocalDate dueDate = null;
        boolean dueDateProvided = false;
        if (request.dueDate().isProvided()) {
            dueDateProvided = true;
            String raw = request.dueDate().getText();
            if (raw != null) {
                dueDate = parseDueDate(raw, violations);
            }
        }

        if (!violations.isEmpty()) {
            throw new FieldValidationException(violations);
        }

        if (titleProvided) {
            task.setTitle(title);
        }
        if (descriptionProvided) {
            task.setDescription(description);
        }
        if (dueDateProvided) {
            task.setDueDate(dueDate);
        }
        if (statusProvided && newStatus != null) {
            TaskStatus from = task.getStatus();
            requireTransition(from, newStatus);
            task.setStatus(newStatus);
            applyCompletionTimestamp(task, from);
        }
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public TaskResponse changeStatus(AuthenticatedUser principal, UUID taskId, UpdateTaskStatusRequest request) {
        Task task = ownedTask(principal.userId(), taskId);
        TaskStatus from = task.getStatus();
        requireTransition(from, request.status());
        task.setStatus(request.status());
        applyCompletionTimestamp(task, from);
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public TaskResponse completeTask(AuthenticatedUser principal, UUID taskId) {
        Task task = ownedTask(principal.userId(), taskId);
        TaskStatus from = task.getStatus();
        requireTransition(from, TaskStatus.COMPLETED);
        task.setStatus(TaskStatus.COMPLETED);
        applyCompletionTimestamp(task, from);
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public TaskResponse cancelTask(AuthenticatedUser principal, UUID taskId) {
        Task task = ownedTask(principal.userId(), taskId);
        requireTransition(task.getStatus(), TaskStatus.CANCELLED);
        task.setStatus(TaskStatus.CANCELLED);
        task.setCompletedAt(null);
        return toResponse(taskRepository.saveAndFlush(task));
    }

    @Transactional
    public void deleteTask(AuthenticatedUser principal, UUID taskId) {
        Task task = ownedTask(principal.userId(), taskId);
        taskRepository.delete(task);
        taskRepository.flush();
    }

    private Task ownedTask(UUID userId, UUID taskId) {
        return taskRepository.findByIdAndUserId(taskId, userId)
                .orElseThrow(TaskNotFoundException::new);
    }

    private TaskQueryFilters parseQuery(TaskListQuery query) {
        List<FieldViolation> violations = new ArrayList<>();

        int page = parseInteger(query.page(), "page", DEFAULT_PAGE, violations);
        if (page < 0) {
            violations.add(new FieldViolation("page", "must be greater than or equal to 0"));
        }

        int size = parseInteger(query.size(), "size", DEFAULT_SIZE, violations);
        if (size < 1) {
            violations.add(new FieldViolation("size", "must be at least 1"));
        } else if (size > maxPageSize) {
            violations.add(new FieldViolation("size", "must be at most " + maxPageSize));
        }

        String sort = blankToNull(query.sort());
        if (sort != null && !SORTABLE_FIELDS.contains(sort)) {
            violations.add(new FieldViolation("sort",
                    "must be one of " + String.join(", ", SORTABLE_FIELDS)));
        }
        String sortField = sort == null ? DEFAULT_SORT_FIELD : sort;

        Sort.Direction direction = DEFAULT_DIRECTION;
        String directionRaw = blankToNull(query.direction());
        if (directionRaw != null) {
            try {
                direction = Sort.Direction.fromString(directionRaw);
            } catch (IllegalArgumentException ex) {
                violations.add(new FieldViolation("direction", "must be ASC or DESC"));
            }
        }

        TaskStatus status = null;
        String statusRaw = blankToNull(query.status());
        if (statusRaw != null) {
            if (statusRaw.equalsIgnoreCase("OVERDUE")) {
                violations.add(new FieldViolation("status",
                        "OVERDUE is a derived flag, not a status; use overdue=true|false"));
            } else {
                try {
                    status = TaskStatus.valueOf(statusRaw);
                } catch (IllegalArgumentException ex) {
                    violations.add(new FieldViolation("status",
                            "must be one of TODO, IN_PROGRESS, COMPLETED, CANCELLED"));
                }
            }
        }

        LocalDate dueDateFrom = parseDate(query.dueDateFrom(), "dueDateFrom", violations);
        LocalDate dueDateTo = parseDate(query.dueDateTo(), "dueDateTo", violations);
        if (dueDateFrom != null && dueDateTo != null && dueDateFrom.isAfter(dueDateTo)) {
            violations.add(new FieldViolation("dueDateFrom", "must not be after dueDateTo"));
        }

        Boolean overdue = null;
        String overdueRaw = blankToNull(query.overdue());
        if (overdueRaw != null) {
            if (overdueRaw.equalsIgnoreCase("true")) {
                overdue = Boolean.TRUE;
            } else if (overdueRaw.equalsIgnoreCase("false")) {
                overdue = Boolean.FALSE;
            } else {
                violations.add(new FieldViolation("overdue", "must be true or false"));
            }
        }

        String search = blankToNull(query.search());
        if (search != null && search.length() > MAX_SEARCH_LENGTH) {
            violations.add(new FieldViolation("search",
                    "must be at most " + MAX_SEARCH_LENGTH + " characters"));
        }

        if (!violations.isEmpty()) {
            throw new FieldValidationException(violations);
        }
        return new TaskQueryFilters(page, size, sortField, direction,
                status, dueDateFrom, dueDateTo, overdue, search);
    }

    private static int parseInteger(String raw, String field, int defaultValue,
                                    List<FieldViolation> violations) {
        if (raw == null || raw.isBlank()) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException ex) {
            violations.add(new FieldViolation(field, "must be an integer"));
            return defaultValue;
        }
    }

    private static LocalDate parseDate(String raw, String field, List<FieldViolation> violations) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(raw.trim());
        } catch (DateTimeParseException ex) {
            violations.add(new FieldViolation(field, "must be a valid ISO-8601 date (yyyy-MM-dd)"));
            return null;
        }
    }

    private static String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private static void requireTransition(TaskStatus from, TaskStatus to) {
        if (from == to) {
            return;
        }
        if (!ALLOWED_TRANSITIONS.get(from).contains(to)) {
            throw new InvalidTaskTransitionException(from, to);
        }
    }

    /**
     * Reconciles {@code completedAt} for the newly set status. A task entering
     * {@code COMPLETED} (or already completed but missing its timestamp) gets a
     * completion instant from the server clock; any other status clears it. The
     * timestamp is never accepted from the client.
     */
    private void applyCompletionTimestamp(Task task, TaskStatus previousStatus) {
        if (task.getStatus() == TaskStatus.COMPLETED) {
            if (previousStatus != TaskStatus.COMPLETED || task.getCompletedAt() == null) {
                task.setCompletedAt(clock.instant());
            }
        } else {
            task.setCompletedAt(null);
        }
    }

    private static String validateTitle(String title, String field, List<FieldViolation> violations) {
        if (title == null) {
            violations.add(new FieldViolation(field, "must not be null"));
            return null;
        }
        String trimmed = title.trim();
        if (trimmed.isEmpty()) {
            violations.add(new FieldViolation(field, "must not be blank"));
        } else if (trimmed.length() > Task.TITLE_MAX_LENGTH) {
            violations.add(new FieldViolation(field,
                    "must be at most " + Task.TITLE_MAX_LENGTH + " characters"));
        }
        return trimmed;
    }

    private static String validateDescription(String raw, List<FieldViolation> violations) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            violations.add(new FieldViolation("description", "must not be blank"));
        } else if (trimmed.length() > Task.DESCRIPTION_MAX_LENGTH) {
            violations.add(new FieldViolation("description",
                    "must be at most " + Task.DESCRIPTION_MAX_LENGTH + " characters"));
        }
        return trimmed;
    }

    private static TaskStatus parseStatus(String text, List<FieldViolation> violations) {
        try {
            return TaskStatus.valueOf(text);
        } catch (IllegalArgumentException ex) {
            violations.add(new FieldViolation("status",
                    "must be one of TODO, IN_PROGRESS, COMPLETED, CANCELLED"));
            return null;
        }
    }

    private static LocalDate parseDueDate(String text, List<FieldViolation> violations) {
        try {
            return LocalDate.parse(text);
        } catch (DateTimeParseException ex) {
            violations.add(new FieldViolation("dueDate",
                    "must be a valid ISO-8601 date (yyyy-MM-dd)"));
            return null;
        }
    }

    private TaskResponse toResponse(Task task) {
        boolean overdue = task.getDueDate() != null
                && task.getDueDate().isBefore(LocalDate.now(clock))
                && task.getStatus() != TaskStatus.COMPLETED
                && task.getStatus() != TaskStatus.CANCELLED;
        return new TaskResponse(
                task.getId(),
                task.getTitle(),
                task.getDescription(),
                task.getStatus(),
                task.getDueDate(),
                task.getCompletedAt(),
                overdue,
                task.getCreatedAt(),
                task.getUpdatedAt(),
                task.getVersion());
    }
}