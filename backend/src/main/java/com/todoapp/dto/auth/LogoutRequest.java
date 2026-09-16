package com.todoapp.dto.auth;

import jakarta.validation.constraints.NotBlank;

/**
 * Revokes a refresh token during logout. The endpoint is deliberately public so
 * a client can revoke before its access token expires; the operation is
 * idempotent and always succeeds for the caller.
 */
public record LogoutRequest(
        @NotBlank(message = "Refresh token is required")
        String refreshToken) {
}