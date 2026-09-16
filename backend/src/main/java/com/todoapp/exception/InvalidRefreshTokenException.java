package com.todoapp.exception;

import org.springframework.http.HttpStatus;

/**
 * The presented refresh token is unknown, already rotated/revoked, or belongs to
 * another account. The client must re-authenticate.
 */
public class InvalidRefreshTokenException extends ApiException {

    public InvalidRefreshTokenException() {
        super(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_INVALID",
                "Refresh token is invalid or has already been used");
    }
}