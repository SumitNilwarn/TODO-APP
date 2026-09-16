package com.todoapp.dto.task;

import com.todoapp.entity.TaskStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Payload for {@code PATCH /api/v1/tasks/{taskId}/status}.
 *
 * <p>The service validates the requested status against the lifecycle rules
 * and reconciles {@code completedAt} accordingly.</p>
 */
public record UpdateTaskStatusRequest(
        @NotNull(message = "Status must not be null")
        TaskStatus status) {
}