package com.todoapp.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * New account credentials. Values are normalized (trimmed, lower-cased) by the
 * service exactly as the {@code User} entity does at persist time, so the
 * registration pre-checks and the database constraints always agree on case.
 */
public record RegisterRequest(
        @NotBlank(message = "Username is required")
        @Size(min = 3, max = 50, message = "Username must be between 3 and 50 characters")
        @Pattern(regexp = "[a-zA-Z0-9._-]+",
                message = "Username may only contain letters, digits, dots, dashes and underscores")
        String username,

        @NotBlank(message = "Email is required")
        @Email(message = "Email must be a valid address")
        @Size(max = 255, message = "Email must be at most 255 characters")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 10, max = 100, message = "Password must be between 10 and 100 characters")
        @Pattern(regexp = ".*[a-zA-Z].*",
                message = "Password must contain at least one letter")
        @Pattern(regexp = ".*\\d.*",
                message = "Password must contain at least one digit")
        String password) {
}