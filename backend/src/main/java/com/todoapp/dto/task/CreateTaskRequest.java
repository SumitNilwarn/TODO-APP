package com.todoapp.dto.task;

import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.validation.NotBlankOrNull;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

/**
 * Payload for {@code POST /api/v1/tasks}.
 *
 * <p>Ownership is never part of the body — the owner is always the
 * authenticated principal. {@code completedAt} is likewise never accepted from
 * the client; when the requested status is {@code COMPLETED} the server sets it
 * from its own clock. Status defaults to {@link TaskStatus#TODO} when omitted.
 * Unknown fields (including any {@code userId} or {@code completedAt}) are
 * deliberately ignored, mirroring the profile API.</p>
 */
public record CreateTaskRequest(
        @NotBlank(message = "Title must not be blank")
        @Size(max = Task.TITLE_MAX_LENGTH,
                message = "Title must be at most 200 characters")
        String title,

        @NotBlankOrNull(message = "Description must not be blank")
        @Size(max = Task.DESCRIPTION_MAX_LENGTH,
                message = "Description must be at most 2000 characters")
        String description,

        TaskStatus status,

        LocalDate dueDate) {
}