package com.todoapp.dto.profile;

import java.time.Instant;
import java.util.UUID;

/**
 * The caller's own profile, as returned by every profile endpoint.
 *
 * <p>Contains profile data plus the owning user's id and the auditing/version
 * fields so clients can detect concurrent modification. Never includes the
 * password hash, security credentials, refresh tokens or any account data.</p>
 */
public record ProfileResponse(
        UUID userId,
        String firstName,
        String lastName,
        String displayName,
        String timezone,
        String profileImageUrl,
        Instant createdAt,
        Instant updatedAt,
        long version) {
}