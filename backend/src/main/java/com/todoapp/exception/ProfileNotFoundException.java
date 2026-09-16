package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when the caller's profile row does not exist (HTTP 404
 * {@code PROFILE_NOT_FOUND}). Reachable on GET and PATCH; a PUT creates the
 * profile instead.
 */
public class ProfileNotFoundException extends ApiException {

    public ProfileNotFoundException() {
        super(HttpStatus.NOT_FOUND, "PROFILE_NOT_FOUND", "Profile not found");
    }
}