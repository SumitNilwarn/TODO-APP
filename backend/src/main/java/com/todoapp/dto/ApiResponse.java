package com.todoapp.dto;

/**
 * Standard envelope for successful REST responses.
 *
 * <pre>
 * {
 *   "success": true,
 *   "data": { ... },
 *   "message": "..."
 * }
 * </pre>
 */
public record ApiResponse<T>(boolean success, T data, String message) {

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null);
    }

    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(true, data, message);
    }
}