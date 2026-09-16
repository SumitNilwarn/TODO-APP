package com.todoapp.dto.task;

import java.util.List;

/**
 * Paginated task-list response.
 *
 * <p>Wrapped in the standard {@link com.todoapp.dto.ApiResponse} envelope as the
 * {@code data} payload. Spring Data {@code Page} is deliberately mapped into this
 * dedicated DTO so no persistence type ever leaks into the API contract.</p>
 *
 * <pre>
 * {
 *   "content": [...],
 *   "page": 0,
 *   "size": 20,
 *   "totalElements": 100,
 *   "totalPages": 5,
 *   "first": true,
 *   "last": false
 * }
 * </pre>
 */
public record TaskPageResponse(
        List<TaskResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean first,
        boolean last) {
}