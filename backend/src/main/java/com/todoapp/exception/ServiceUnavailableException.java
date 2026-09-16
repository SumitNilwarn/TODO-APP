package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a required dependency (such as the database) is not reachable
 * (HTTP 503 SERVICE_UNAVAILABLE).
 */
public class ServiceUnavailableException extends ApiException {

    public ServiceUnavailableException(String message) {
        super(HttpStatus.SERVICE_UNAVAILABLE, "SERVICE_UNAVAILABLE", message);
    }

    public ServiceUnavailableException(String message, Throwable cause) {
        super(HttpStatus.SERVICE_UNAVAILABLE, "SERVICE_UNAVAILABLE", message, cause);
    }
}