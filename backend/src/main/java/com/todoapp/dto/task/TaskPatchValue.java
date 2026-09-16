package com.todoapp.dto.task;

/**
 * Marks whether a JSON object field was present in a task PATCH request body —
 * including an explicit {@code null} — versus omitted entirely.
 *
 * <p>Task PATCH semantics need three distinct states per field:
 * <ul>
 *   <li>omitted → leave the current value unchanged;</li>
 *   <li>explicit {@code null} → clear the field (allowed for the optional
 *       {@code description}/{@code dueDate}, rejected for {@code title},
 *       {@code status});</li>
 *   <li>a string → validate, normalize and store it.</li>
 * </ul>
 * The raw text is preserved so the service can parse/validate each field with
 * the correct semantics. Produced by {@link TaskPatchValueDeserializer}.</p>
 */
public final class TaskPatchValue {

    private final boolean provided;
    private final String text;

    private TaskPatchValue(boolean provided, String text) {
        this.provided = provided;
        this.text = text;
    }

    public static TaskPatchValue omitted() {
        return new TaskPatchValue(false, null);
    }

    public static TaskPatchValue ofNull() {
        return new TaskPatchValue(true, null);
    }

    public static TaskPatchValue of(String text) {
        return new TaskPatchValue(true, text);
    }

    public boolean isProvided() {
        return provided;
    }

    public String getText() {
        return text;
    }
}