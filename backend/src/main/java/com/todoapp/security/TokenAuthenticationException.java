package com.todoapp.security;

import org.springframework.security.core.AuthenticationException;

/**
 * Signals that a presented JWT access token could not be authenticated: either
 * it expired or it is malformed/forged. Carries a stable machine-readable code
 * ({@code TOKEN_EXPIRED} / {@code TOKEN_INVALID}) so the REST entry point can
 * produce a precise {@code ApiError} even though the filter stage runs outside
 * {@link com.todoapp.exception.GlobalExceptionHandler}.
 */
public class TokenAuthenticationException extends AuthenticationException {

    private final String code;

    public TokenAuthenticationException(String code, String message, Throwable cause) {
        super(message, cause);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}