package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a request or operation is invalid (HTTP 400 BAD_REQUEST).
 */
public class BadRequestException extends ApiException {

    public BadRequestException(String message) {
        super(HttpStatus.BAD_REQUEST, "BAD_REQUEST", message);
    }

    public BadRequestException(String message, Throwable cause) {
        super(HttpStatus.BAD_REQUEST, "BAD_REQUEST", message, cause);
    }
}