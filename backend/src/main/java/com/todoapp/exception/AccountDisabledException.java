package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * The account exists but has been disabled by an administrator. Login and token
 * validation reject the account regardless of correct credentials.
 */
public class AccountDisabledException extends ApiException {

    public AccountDisabledException() {
        super(HttpStatus.FORBIDDEN, "ACCOUNT_DISABLED",
                "This account has been disabled");
    }
}