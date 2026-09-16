package com.todoapp.dto.auth;

/**
 * Refreshes an expired access token using a previously issued opaque refresh
 * token. The refresh token is rotated: the presented token is revoked and a new
 * one is returned alongside a fresh access token.
 *
 * <p>Blank or absent values are intentionally not validated here: the service
 * layer rejects them with the standardized 401 {@code REFRESH_TOKEN_INVALID}
 * envelope instead of a 400 field-level validation error.</p>
 */
public record RefreshRequest(
        String refreshToken) {
}