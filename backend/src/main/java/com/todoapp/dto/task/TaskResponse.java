package com.todoapp.dto.task;

import com.todoapp.entity.TaskStatus;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A task owned by the authenticated caller, as returned by every task endpoint.
 *
 * <p>{@code overdue} is a <strong>derived</strong> flag computed at response
 * time from the persisted row: true when {@code dueDate} has passed and the
 * task is neither {@code COMPLETED} nor {@code CANCELLED}. It is never
 * persisted. The auditing/version fields let clients detect concurrent
 * modification and drive optimistic locking.</p>
 */
public record TaskResponse(
        UUID id,
        String title,
        String description,
        TaskStatus status,
        LocalDate dueDate,
        Instant completedAt,
        boolean overdue,
        Instant createdAt,
        Instant updatedAt,
        long version) {
}