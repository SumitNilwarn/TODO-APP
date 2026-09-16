package com.todoapp.entity;

/**
 * Lifecycle state of a user account.
 *
 * <p>Stored in the database as a plain string (see the {@code CHECK} constraint
 * on {@code users.account_status}) and kept extensible for future states such as
 * password-expiry or pending-verification.</p>
 */
public enum AccountStatus {
    ACTIVE,
    DISABLED,
    LOCKED
}