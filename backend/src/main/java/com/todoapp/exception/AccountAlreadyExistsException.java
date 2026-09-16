package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * Registration raced with another request and a uniqueness constraint fired
 * before the application-level pre-check, even though neither username nor
 * email was reported taken. The client may pick a different identity and retry.
 */
public class AccountAlreadyExistsException extends ApiException {

    public AccountAlreadyExistsException() {
        super(HttpStatus.CONFLICT, "ACCOUNT_ALREADY_EXISTS",
                "An account with these details already exists");
    }
}