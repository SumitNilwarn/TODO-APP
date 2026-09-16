package com.todoapp.dto.auth;

/**
 * Token pair returned by login and refresh.
 *
 * <p>{@code accessToken} is a short-lived JWT used in the Authorization header;
 * {@code refreshToken} is an opaque, single-use token persisted only as a SHA-256
 * hash server-side. {@code expiresIn} is the access token lifetime in seconds.</p>
 */
public record TokenResponse(String accessToken, String refreshToken, String tokenType, long expiresIn) {

    public static TokenResponse of(String accessToken, String refreshToken, long expiresIn) {
        return new TokenResponse(accessToken, refreshToken, "Bearer", expiresIn);
    }
}