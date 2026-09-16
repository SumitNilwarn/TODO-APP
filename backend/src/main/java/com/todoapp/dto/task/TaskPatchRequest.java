package com.todoapp.dto.task;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

/**
 * Partial update of a task ({@code PATCH /api/v1/tasks/{taskId}}).
 *
 * <p>Each field is a {@link TaskPatchValue} that distinguishes:
 * <ul>
 *   <li>omitted → the field stays unchanged;</li>
 *   <li>explicit {@code null} → clears the optional
 *       {@code description}/{@code dueDate} (rejected for required
 *       {@code title} and {@code status});</li>
 *   <li>a string → validated and stored by the service (status is parsed to
 *       one of the four persisted lifecycle states, dueDate to an ISO-8601
 *       date).</li>
 * </ul>
 * {@code completedAt} can never be patched — it is reconciled server-side from
 * the resulting status. A {@code {}} body is a no-op.</p>
 */
public final class TaskPatchRequest {

    private TaskPatchValue title = TaskPatchValue.omitted();
    private TaskPatchValue description = TaskPatchValue.omitted();
    private TaskPatchValue status = TaskPatchValue.omitted();
    private TaskPatchValue dueDate = TaskPatchValue.omitted();

    public TaskPatchRequest() {
    }

    private static TaskPatchValue nullToPatchValue(TaskPatchValue value) {
        return value == null ? TaskPatchValue.ofNull() : value;
    }

    public TaskPatchValue title() {
        return title;
    }

    public TaskPatchValue description() {
        return description;
    }

    public TaskPatchValue status() {
        return status;
    }

    public TaskPatchValue dueDate() {
        return dueDate;
    }

    @JsonDeserialize(using = TaskPatchValueDeserializer.class)
    public void setTitle(TaskPatchValue value) {
        this.title = nullToPatchValue(value);
    }

    @JsonDeserialize(using = TaskPatchValueDeserializer.class)
    public void setDescription(TaskPatchValue value) {
        this.description = nullToPatchValue(value);
    }

    @JsonDeserialize(using = TaskPatchValueDeserializer.class)
    public void setStatus(TaskPatchValue value) {
        this.status = nullToPatchValue(value);
    }

    @JsonDeserialize(using = TaskPatchValueDeserializer.class)
    public void setDueDate(TaskPatchValue value) {
        this.dueDate = nullToPatchValue(value);
    }
}