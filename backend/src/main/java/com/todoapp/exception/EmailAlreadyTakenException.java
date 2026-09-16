package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Registration attempted to create an account whose email (case-insensitive) is
 * already in use.
 */
public class EmailAlreadyTakenException extends ApiException {

    public EmailAlreadyTakenException() {
        super(HttpStatus.CONFLICT, "EMAIL_ALREADY_TAKEN",
                "Email is already registered");
    }
}