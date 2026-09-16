package com.todoapp.repository;

import com.todoapp.entity.RefreshToken;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Persistence access for {@link RefreshToken}.
 *
 * <p>{@code findByTokenHash} is the hot path for logout and rotation: the token
 * hash is unique, so the lookup is a single indexed read. Batch cleanup of
 * expired or revoked sessions is intentionally delegated to a later maintenance
 * job/DDL rather than run inline on request paths.</p>
 */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    void deleteAllByUserId(UUID userId);

    long countByUserId(UUID userId);
}