package com.todoapp.dto.task;

/**
 * Raw query parameters for {@code GET /api/v1/tasks}.
 *
 * <p>All values are kept as unparsed strings: {@link com.todoapp.service.TaskService}
 * parses and validates them into a {@link TaskQueryFilters}, producing the
 * standard {@code VALIDATION_ERROR} envelope with field-level details when any
 * parameter is unusable (mirroring the programmatic PATCH validation of
 * Phases 5/6). Blank values are treated as absent.</p>
 */
public record TaskListQuery(
        String page,
        String size,
        String sort,
        String direction,
        String status,
        String dueDateFrom,
        String dueDateTo,
        String overdue,
        String search) {
}