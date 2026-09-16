package com.todoapp.exception;

import com.todoapp.entity.TaskStatus;
import org.springframework.http.HttpStatus;

/**
 * Thrown when a task status change violates the lifecycle rules (HTTP 409
 * {@code INVALID_TRANSITION}). Terminal states ({@code COMPLETED},
 * {@code CANCELLED}) cannot be reopened through the normal lifecycle APIs.
 */
public class InvalidTaskTransitionException extends ApiException {

    public InvalidTaskTransitionException(TaskStatus from, TaskStatus to) {
        super(HttpStatus.CONFLICT, "INVALID_TRANSITION",
                "Cannot update task status from " + from + " to " + to);
    }
}