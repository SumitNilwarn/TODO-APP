package com.todoapp.dto.auth;

import java.util.UUID;

/**
 * Result of a successful registration. Only stable identity data is returned;
 * the caller immediately proceeds to login for credentials.
 */
public record RegisterResponse(UUID userId, String username) {
}