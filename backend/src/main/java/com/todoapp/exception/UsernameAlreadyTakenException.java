package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Registration attempted to create an account whose username (case-insensitive)
 * is already taken.
 */
public class UsernameAlreadyTakenException extends ApiException {

    public UsernameAlreadyTakenException() {
        super(HttpStatus.CONFLICT, "USERNAME_ALREADY_TAKEN",
                "Username is already taken");
    }
}