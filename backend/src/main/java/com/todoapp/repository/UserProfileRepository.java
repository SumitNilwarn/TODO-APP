package com.todoapp.repository;

import com.todoapp.entity.UserProfile;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Persistence access for {@link UserProfile}.
 *
 * <p>The unique constraint on {@code user_id} guarantees a single profile per
 * user; {@code findByUserId} is the primary access pattern for profile reads.</p>
 */
public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {

    Optional<UserProfile> findByUserId(UUID userId);
}