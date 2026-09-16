package com.todoapp.service;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;

class PasswordServiceTest {

    private static final String PASSWORD = "S3cure-password-42!";

    private final PasswordService passwordService = new PasswordService(new BCryptPasswordEncoder());

    @Test
    void hashDoesNotStorePlaintext() {
        assertThat(passwordService.hash(PASSWORD)).isNotEqualTo(PASSWORD);
    }

    @Test
    void matchingPasswordIsVerified() {
        String hash = passwordService.hash(PASSWORD);
        assertThat(passwordService.matches(PASSWORD, hash)).isTrue();
    }

    @Test
    void wrongPasswordIsRejected() {
        String hash = passwordService.hash(PASSWORD);
        assertThat(passwordService.matches("wrong-password", hash)).isFalse();
    }

    @Test
    void hashesAreSaltedAndThusDiffer() {
        assertThat(passwordService.hash(PASSWORD)).isNotEqualTo(passwordService.hash(PASSWORD));
    }
}