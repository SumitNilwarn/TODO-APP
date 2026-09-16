package com.todoapp.entity;

/**
 * Persisted lifecycle state of a task.
 *
 * <p>{@code OVERDUE} is deliberately <strong>not</strong> a persisted status.
 * "Overdue" is a derived business state (due date passed, not completed, not
 * cancelled) that is computed at runtime by application logic in a later phase.
 * Only the real lifecycle states above are stored, and the database {@code CHECK}
 * constraint on {@code tasks.status} enforces exactly these four values.</p>
 */
public enum TaskStatus {
    TODO,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED
}