package com.todoapp.controller;

import com.todoapp.dto.ApiResponse;
import com.todoapp.dto.task.CreateTaskRequest;
import com.todoapp.dto.task.TaskListQuery;
import com.todoapp.dto.task.TaskPageResponse;
import com.todoapp.dto.task.TaskPatchRequest;
import com.todoapp.dto.task.TaskResponse;
import com.todoapp.dto.task.UpdateTaskRequest;
import com.todoapp.dto.task.UpdateTaskStatusRequest;
import com.todoapp.security.principal.AuthenticatedUser;
import com.todoapp.service.TaskService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Authenticated task management (Phase 6).
 *
 * <p>Every endpoint operates exclusively on the tasks owned by the
 * authenticated principal; no client-supplied user id is accepted, so
 * cross-user access is impossible. A task that is missing — or belongs to
 * someone else — is reported as the same 404 {@code TASK_NOT_FOUND}.</p>
 */
@RestController
@RequestMapping(ApiPaths.TASKS)
@Tag(name = "Tasks",
        description = "Authenticated task management (Phase 6): CRUD and lifecycle operations.")
public class TaskController {

    private final TaskService taskService;

    public TaskController(TaskService taskService) {
        this.taskService = taskService;
    }

    @PostMapping
    @Operation(summary = "Create a task",
            description = "Creates a task owned by the authenticated user. Status defaults to TODO; "
                    + "when COMPLETED is requested the completedAt timestamp is taken from the server "
                    + "clock. Ownership and completedAt are never accepted from the client.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "Task created"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Validation failed (VALIDATION_ERROR)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> createTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody CreateTaskRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, taskService.createTask(principal, request), "Task created"));
    }

    @GetMapping("/{taskId}")
    @Operation(summary = "Get one task",
            description = "Returns the caller's task. A task that does not exist or belongs to another "
                    + "user returns 404 TASK_NOT_FOUND.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task returned"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Malformed task id (INVALID_PARAMETER)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> getTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId) {
        return ResponseEntity.ok(ApiResponse.success(taskService.getTask(principal, taskId)));
    }

    @PutMapping("/{taskId}")
    @Operation(summary = "Replace a task",
            description = "Full replacement of the caller's task: title, description, status and "
                    + "dueDate are all set from the body (null clears the optional fields). Status must "
                    + "be supplied and must obey the lifecycle rules; completedAt is reconciled "
                    + "server-side. createdAt is preserved.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task replaced"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Validation failed (VALIDATION_ERROR)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Invalid transition (INVALID_TRANSITION) "
                    + "or concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> updateTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId,
            @Valid @RequestBody UpdateTaskRequest request) {
        return ResponseEntity.ok(ApiResponse.success(taskService.updateTask(principal, taskId, request)));
    }

    @PatchMapping("/{taskId}")
    @Operation(summary = "Partially update a task",
            description = "Only fields present in the body are changed: an explicit null clears "
                    + "description/dueDate, an omitted field is left untouched and {} is a no-op. "
                    + "Status changes must obey the lifecycle rules; completedAt is reconciled "
                    + "server-side.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task updated"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Validation failed (VALIDATION_ERROR)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Invalid transition (INVALID_TRANSITION) "
                    + "or concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> patchTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId,
            @RequestBody TaskPatchRequest request) {
        return ResponseEntity.ok(ApiResponse.success(taskService.patchTask(principal, taskId, request)));
    }

    @DeleteMapping("/{taskId}")
    @Operation(summary = "Delete a task",
            description = "Deletes the caller's task. Deleting another user's task is impossible and "
                    + "reports 404 TASK_NOT_FOUND.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task deleted"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<Void>> deleteTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId) {
        taskService.deleteTask(principal, taskId);
        return ResponseEntity.ok(new ApiResponse<>(true, null, "Task deleted"));
    }

    @PatchMapping("/{taskId}/status")
    @Operation(summary = "Change task status",
            description = "Sets the caller's task status, enforcing the lifecycle rules and "
                    + "reconciling completedAt. Same-status requests are idempotent no-ops.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Status changed"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Validation failed (VALIDATION_ERROR)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Invalid transition (INVALID_TRANSITION) "
                    + "or concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> changeStatus(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId,
            @Valid @RequestBody UpdateTaskStatusRequest request) {
        return ResponseEntity.ok(ApiResponse.success(taskService.changeStatus(principal, taskId, request)));
    }

    @PatchMapping("/{taskId}/complete")
    @Operation(summary = "Complete a task",
            description = "Marks the caller's task COMPLETED, setting completedAt from the server "
                    + "clock. Idempotent for already-completed tasks; rejected for cancelled tasks.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task completed"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Invalid transition (INVALID_TRANSITION) "
                    + "or concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> completeTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId) {
        return ResponseEntity.ok(ApiResponse.success(taskService.completeTask(principal, taskId)));
    }

    @PatchMapping("/{taskId}/cancel")
    @Operation(summary = "Cancel a task",
            description = "Marks the caller's task CANCELLED and clears any completedAt. Idempotent "
                    + "for already-cancelled tasks; rejected for completed tasks.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Task cancelled"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "Task not found (TASK_NOT_FOUND)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "Invalid transition (INVALID_TRANSITION) "
                    + "or concurrent modification (OPTIMISTIC_LOCK_CONFLICT)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskResponse>> cancelTask(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @PathVariable UUID taskId) {
        return ResponseEntity.ok(ApiResponse.success(taskService.cancelTask(principal, taskId)));
    }

    @GetMapping
    @Operation(summary = "List tasks (advanced)",
            description = "Returns the authenticated user's tasks, scoped to the JWT principal. "
                    + "Supports pagination (page/size, maximum page size configured via "
                    + "app.tasks.max-page-size, default 100), sorting (sort field from the allowlist "
                    + "createdAt|updatedAt|dueDate|title|status, direction ASC|DESC, default "
                    + "createdAt DESC with a deterministic id tie-breaker), status filtering "
                    + "(TODO|IN_PROGRESS|COMPLETED|CANCELLED — OVERDUE is a derived flag and must be "
                    + "requested via overdue=true|false), an inclusive LocalDate due-date range "
                    + "(dueDateFrom/dueDateTo), the derived overdue flag, and a case-insensitive "
                    + "partial search over title/description. Blank values are treated as absent. "
                    + "Responses use the paginated TaskPageResponse in the data envelope.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Paginated tasks returned"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "Invalid query parameter (VALIDATION_ERROR)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<TaskPageResponse>> listTasks(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Parameter(description = "Zero-based page index (default 0).", example = "0")
            @RequestParam(defaultValue = "0") String page,
            @Parameter(description = "Page size, between 1 and app.tasks.max-page-size (default 20).", example = "20")
            @RequestParam(defaultValue = "20") String size,
            @Parameter(description = "Sort field: createdAt, updatedAt, dueDate, title or status (default createdAt).", example = "createdAt")
            @RequestParam(required = false) String sort,
            @Parameter(description = "Sort direction: ASC or DESC (default DESC).", example = "DESC")
            @RequestParam(required = false) String direction,
            @Parameter(description = "Status filter: TODO, IN_PROGRESS, COMPLETED or CANCELLED. OVERDUE is rejected; use overdue instead.", example = "IN_PROGRESS")
            @RequestParam(required = false) String status,
            @Parameter(description = "Inclusive lower bound on dueDate (ISO-8601 date).", example = "2026-08-01")
            @RequestParam(required = false) String dueDateFrom,
            @Parameter(description = "Inclusive upper bound on dueDate (ISO-8601 date). Null due dates never match a date range.", example = "2026-08-31")
            @RequestParam(required = false) String dueDateTo,
            @Parameter(description = "Derived-overdue filter: true matches tasks with a dueDate before today that are not COMPLETED/CANCELLED; false matches everything else (including tasks without a dueDate).", example = "true")
            @RequestParam(required = false) String overdue,
            @Parameter(description = "Case-insensitive partial search over title and description (trimmed; blank = no filter).", example = "report")
            @RequestParam(required = false) String search) {
        TaskListQuery query = new TaskListQuery(
                page, size, sort, direction, status, dueDateFrom, dueDateTo, overdue, search);
        return ResponseEntity.ok(ApiResponse.success(taskService.listTasks(principal, query)));
    }
}