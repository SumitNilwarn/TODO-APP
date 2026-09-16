package com.todoapp.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Locale;

/**
 * Application account. Holds only account/security-related data; profile data
 * lives in {@link UserProfile}.
 *
 * <p>Username and email are normalized (trimmed and lower-cased) before every
 * persist/update so the database uniqueness constraints provide a
 * case-insensitive uniqueness guarantee. The database additionally enforces the
 * normalized form with {@code CHECK (col = lower(col))} constraints.</p>
 *
 * <p>{@code passwordHash} is a persistence-only field and is never exposed in
 * API DTOs. Hashing/verification is implemented in the authentication phase.</p>
 */
@Entity
@Table(name = "users")
public class User extends BaseEntity {

    public static final int USERNAME_MAX_LENGTH = 50;
    public static final int EMAIL_MAX_LENGTH = 255;
    public static final int PASSWORD_HASH_MAX_LENGTH = 255;

    @Column(name = "username", nullable = false, length = USERNAME_MAX_LENGTH)
    private String username;

    @Column(name = "email", nullable = false, length = EMAIL_MAX_LENGTH)
    private String email;

    @Column(name = "password_hash", nullable = false, length = PASSWORD_HASH_MAX_LENGTH)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(name = "account_status", nullable = false, length = 20)
    private AccountStatus accountStatus = AccountStatus.ACTIVE;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    protected User() {
    }

    public User(String username, String email, String passwordHash) {
        this.username = username;
        this.email = email;
        this.passwordHash = passwordHash;
    }

    @PrePersist
    @PreUpdate
    void normalize() {
        this.username = username == null ? null : username.trim().toLowerCase(Locale.ROOT);
        this.email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    public String getUsername() {
        return username;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public AccountStatus getAccountStatus() {
        return accountStatus;
    }

    public void setAccountStatus(AccountStatus accountStatus) {
        this.accountStatus = accountStatus;
    }

    public Instant getLastLoginAt() {
        return lastLoginAt;
    }

    public void setLastLoginAt(Instant lastLoginAt) {
        this.lastLoginAt = lastLoginAt;
    }
}