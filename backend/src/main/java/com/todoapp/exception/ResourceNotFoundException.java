package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a requested resource does not exist (HTTP 404 NOT_FOUND).
 */
public class ResourceNotFoundException extends ApiException {

    public ResourceNotFoundException(String message) {
        super(HttpStatus.NOT_FOUND, "NOT_FOUND", message);
    }

    public ResourceNotFoundException(String message, Throwable cause) {
        super(HttpStatus.NOT_FOUND, "NOT_FOUND", message, cause);
    }
}