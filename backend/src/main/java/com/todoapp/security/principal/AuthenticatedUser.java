package com.todoapp.security.principal;

import java.util.UUID;

/**
 * Authenticated caller identity placed in the {@code SecurityContext} by the JWT
 * filter.
 *
 * <p>Deliberately a lightweight value type (not the {@link com.todoapp.entity.User}
 * entity). The JPA entity is persisted state; the principal is the caller-facing
 * identity available to controllers and services.</p>
 */
public record AuthenticatedUser(UUID userId, String username) {
}