package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * The presented refresh token has passed its maximum lifetime. Unlike an invalid
 * token it is still authentic, so the client can tell "log in again" apart from
 * "token was already used".
 */
public class ExpiredRefreshTokenException extends ApiException {

    public ExpiredRefreshTokenException() {
        super(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_EXPIRED",
                "Refresh token has expired, please sign in again");
    }
}