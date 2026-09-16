package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * The account exists but has been locked (e.g. repeated failed attempts or an
 * administrator action). Login and token validation reject the account.
 */
public class AccountLockedException extends ApiException {

    public AccountLockedException() {
        super(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED",
                "This account has been locked");
    }
}