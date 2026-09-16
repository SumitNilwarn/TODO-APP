package com.todoapp.repository;

import com.todoapp.entity.User;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Persistence access for {@link User}.
 *
 * <p>Username/email uniqueness is guaranteed by the database; the derived
 * {@code findBy*} methods serve the planned authentication and profile phases.
 * Input values are expected to be already normalized (lowercase) as enforced by
 * the entity and database constraints.</p>
 */
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);
}