package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Base exception for controlled API errors.
 * <p>
 * Each subclass maps to a specific HTTP status and stable machine-readable error code.
 * Services throw these; the {@link GlobalExceptionHandler} translates them into the
 * standard {@code ApiError} envelope without exposing implementation details.
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public ApiException(HttpStatus status, String code, String message, Throwable cause) {
        super(message, cause);
        this.status = status;
        this.code = code;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }
}