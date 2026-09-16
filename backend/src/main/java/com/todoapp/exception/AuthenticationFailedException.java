package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Login failed because the credentials were invalid (unknown username/email or
 * wrong password). Deliberately generic to avoid account enumeration.
 */
public class AuthenticationFailedException extends ApiException {

    public AuthenticationFailedException() {
        super(HttpStatus.UNAUTHORIZED, "AUTHENTICATION_FAILED",
                "Invalid username or password");
    }
}