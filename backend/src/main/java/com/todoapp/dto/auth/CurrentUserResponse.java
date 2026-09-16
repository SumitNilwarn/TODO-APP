package com.todoapp.dto.auth;

import java.util.UUID;

/**
 * Identity of the authenticated caller, returned by the protected
 * {@code /api/v1/auth/me} endpoint. Never includes the password hash.
 */
public record CurrentUserResponse(UUID userId, String username, String email) {
}