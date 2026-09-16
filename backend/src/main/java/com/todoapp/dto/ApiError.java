package com.todoapp.dto;

import java.time.Instant;
import java.util.List;

/**
 * Standard envelope for error REST responses.
 *
 * <pre>
 * {
 *   "success": false,
 *   "error": { "code": "...", "message": "...", "details": [] },
 *   "timestamp": "...",
 *   "path": "..."
 * }
 * </pre>
 */
public record ApiError(boolean success, ErrorDetail error, Instant timestamp, String path) {

    public static ApiError of(String code, String message, Instant timestamp, String path) {
        return new ApiError(false, new ErrorDetail(code, message, List.of()), timestamp, path);
    }

    public static ApiError of(String code, String message, List<FieldViolation> details,
                              Instant timestamp, String path) {
        return new ApiError(false, new ErrorDetail(code, message, details), timestamp, path);
    }
}