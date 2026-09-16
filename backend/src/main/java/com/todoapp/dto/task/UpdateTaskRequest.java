package com.todoapp.dto.task;

import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.validation.NotBlankOrNull;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

/**
 * Payload for {@code PUT /api/v1/tasks/{taskId}} — full replacement.
 *
 * <p>Every editable field is replaced by the body: {@code null} clears
 * {@code description}/{@code dueDate}. Status is required so a full replace
 * never silently resets a terminal task; the service enforces lifecycle
 * transition rules on it. {@code completedAt} is never client-controlled — the
 * server sets it when the resulting status is {@code COMPLETED}.</p>
 */
public record UpdateTaskRequest(
        @NotBlank(message = "Title must not be blank")
        @Size(max = Task.TITLE_MAX_LENGTH,
                message = "Title must be at most 200 characters")
        String title,

        @NotBlankOrNull(message = "Description must not be blank")
        @Size(max = Task.DESCRIPTION_MAX_LENGTH,
                message = "Description must be at most 2000 characters")
        String description,

        @NotNull(message = "Status must not be null")
        TaskStatus status,

        LocalDate dueDate) {
}