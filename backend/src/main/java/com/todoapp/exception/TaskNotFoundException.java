package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a task cannot be found (HTTP 404 {@code TASK_NOT_FOUND}).
 *
 * <p>Ownership-aware lookups use the authenticated user's id, so a task that
 * exists but belongs to another user looks identical to a task that never
 * existed — cross-user data is never leaked (IDOR-safe by construction).</p>
 */
public class TaskNotFoundException extends ApiException {

    public TaskNotFoundException() {
        super(HttpStatus.NOT_FOUND, "TASK_NOT_FOUND", "Task not found");
    }
}