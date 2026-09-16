package com.todoapp.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

/**
 * Thin wrapper around the Spring Security {@link PasswordEncoder} (BCrypt).
 * <p>
 * Isolates password hashing so the rest of the authentication stack only ever
 * deals with hashes, never plaintext.</p>
 */
@Service
public class PasswordService {

    private final PasswordEncoder passwordEncoder;

    public PasswordService(PasswordEncoder passwordEncoder) {
        this.passwordEncoder = passwordEncoder;
    }

    public String hash(String rawPassword) {
        return passwordEncoder.encode(rawPassword);
    }

    public boolean matches(String rawPassword, String encodedHash) {
        return passwordEncoder.matches(rawPassword, encodedHash);
    }
}