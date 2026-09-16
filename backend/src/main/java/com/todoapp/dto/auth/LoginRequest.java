package com.todoapp.dto.auth;

import jakarta.validation.constraints.NotBlank;

/**
 * Login credentials.
 * <p>
 * The username field accepts either the account username or the account email;
 * the service resolves which one was supplied. Login uses {@code username}
 * rather than a user id because the caller cannot know it yet.
 */
public record LoginRequest(
        @NotBlank(message = "Username is required")
        String username,

        @NotBlank(message = "Password is required")
        String password) {
}