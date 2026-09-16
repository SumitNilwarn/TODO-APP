package com.todoapp.service;

import com.todoapp.dto.FieldViolation;
import com.todoapp.dto.profile.PatchField;
import com.todoapp.dto.profile.ProfilePatchRequest;
import com.todoapp.dto.profile.ProfileResponse;
import com.todoapp.dto.profile.ProfileUpdateRequest;
import com.todoapp.dto.profile.ProfileUpdateResult;
import com.todoapp.entity.User;
import com.todoapp.entity.UserProfile;
import com.todoapp.exception.FieldValidationException;
import com.todoapp.exception.ProfileNotFoundException;
import com.todoapp.repository.UserProfileRepository;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.principal.AuthenticatedUser;
import com.todoapp.validation.HttpUrlValidator;
import com.todoapp.validation.TimezoneValidator;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.function.BiConsumer;
import java.util.function.Predicate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reads and writes the authenticated caller's own profile.
 *
 * <p>User identity always comes from the {@link AuthenticatedUser} principal
 * established by the JWT filter; no client-supplied identifier is ever used to
 * select a profile, so cross-user access (IDOR) is impossible by construction —
 * the repository is always queried by {@code principal.userId()}.</p>
 *
 * <p>Semantics:
 * <ul>
 *   <li><b>GET</b> — returns the caller's profile or 404
 *       {@code PROFILE_NOT_FOUND}.</li>
 *   <li><b>PUT</b> — full replace; creates the profile on first use (201) and
 *       updates it afterwards (200).</li>
 *   <li><b>PATCH</b> — partial update; omitted fields are left unchanged,
 *       explicit {@code null} clears a field, provided values are validated and
 *       stored.</li>
 * </ul>
 * Strings are trimmed before persistence so accidental surrounding whitespace
 * never lands in the database, while optional fields remain {@code null}.</p>
 *
 * <p>Optimistic locking is preserved: {@code UserProfile} keeps its
 * {@code @Version}; concurrent updates surface as
 * {@link org.springframework.dao.OptimisticLockingFailureException}, translated
 * by the exception handler into a 409 {@code OPTIMISTIC_LOCK_CONFLICT}.</p>
 */
@Service
public class ProfileService {

    private final UserProfileRepository profileRepository;
    private final UserRepository userRepository;

    public ProfileService(UserProfileRepository profileRepository, UserRepository userRepository) {
        this.profileRepository = profileRepository;
        this.userRepository = userRepository;
    }

    /** Validation rules for individually patchable string fields. */
    private record FieldRule(int maxLength, Predicate<String> validFormat, String formatMessage,
                             BiConsumer<UserProfile, String> setter) {
    }

    private static final FieldRule FIRST_NAME = new FieldRule(
            UserProfile.NAME_MAX_LENGTH,
            value -> true,
            null,
            UserProfile::setFirstName);

    private static final FieldRule LAST_NAME = new FieldRule(
            UserProfile.NAME_MAX_LENGTH,
            value -> true,
            null,
            UserProfile::setLastName);

    private static final FieldRule DISPLAY_NAME = new FieldRule(
            UserProfile.DISPLAY_NAME_MAX_LENGTH,
            value -> true,
            null,
            UserProfile::setDisplayName);

    private static final FieldRule TIMEZONE = new FieldRule(
            UserProfile.TIMEZONE_MAX_LENGTH,
            TimezoneValidator::isValidTimezone,
            "must be a valid IANA timezone identifier (e.g. Asia/Kolkata) or UTC/GMT",
            UserProfile::setTimezone);

    private static final FieldRule PROFILE_IMAGE_URL = new FieldRule(
            UserProfile.PROFILE_IMAGE_URL_MAX_LENGTH,
            HttpUrlValidator::isValidHttpUrl,
            "must be a valid http(s) URL",
            UserProfile::setProfileImageUrl);

    @Transactional(readOnly = true)
    public ProfileResponse getProfile(AuthenticatedUser principal) {
        UUID userId = principal.userId();
        UserProfile profile = profileRepository.findByUserId(userId)
                .orElseThrow(ProfileNotFoundException::new);
        return toResponse(userId, profile);
    }

    @Transactional
    public ProfileUpdateResult updateProfile(AuthenticatedUser principal, ProfileUpdateRequest request) {
        UUID userId = principal.userId();
        UserProfile profile = profileRepository.findByUserId(userId).orElse(null);
        boolean created = profile == null;
        if (created) {
            profile = new UserProfile(userRef(userId), null, null, null, null, null);
        }
        applyAll(profile, request);
        return new ProfileUpdateResult(created, toResponse(userId, profileRepository.saveAndFlush(profile)));
    }

    @Transactional
    public ProfileResponse patchProfile(AuthenticatedUser principal, ProfilePatchRequest request) {
        UUID userId = principal.userId();
        UserProfile profile = profileRepository.findByUserId(userId)
                .orElseThrow(ProfileNotFoundException::new);
        List<FieldViolation> violations = new ArrayList<>();

        applyPatch(profile, request.firstName(), FIRST_NAME, "firstName", violations);
        applyPatch(profile, request.lastName(), LAST_NAME, "lastName", violations);
        applyPatch(profile, request.displayName(), DISPLAY_NAME, "displayName", violations);
        applyPatch(profile, request.timezone(), TIMEZONE, "timezone", violations);
        applyPatch(profile, request.profileImageUrl(), PROFILE_IMAGE_URL, "profileImageUrl", violations);

        if (!violations.isEmpty()) {
            throw new FieldValidationException(violations);
        }
        return toResponse(userId, profileRepository.saveAndFlush(profile));
    }

    private User userRef(UUID userId) {
        return userRepository.getReferenceById(userId);
    }

    private static void applyAll(UserProfile profile, ProfileUpdateRequest request) {
        profile.setFirstName(normalize(request.firstName()));
        profile.setLastName(normalize(request.lastName()));
        profile.setDisplayName(normalize(request.displayName()));
        profile.setTimezone(normalize(request.timezone()));
        profile.setProfileImageUrl(normalize(request.profileImageUrl()));
    }

    private static void applyPatch(UserProfile profile, PatchField field, FieldRule rule,
                                   String fieldName, List<FieldViolation> violations) {
        if (field == null || !field.isProvided()) {
            return;
        }
        String value = field.getValue();
        if (value == null) {
            rule.setter().accept(profile, null);
            return;
        }
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            violations.add(new FieldViolation(fieldName, "must not be blank"));
            return;
        }
        if (normalized.length() > rule.maxLength()) {
            violations.add(new FieldViolation(fieldName,
                    "must be at most " + rule.maxLength() + " characters"));
            return;
        }
        if (!rule.validFormat().test(normalized)) {
            violations.add(new FieldViolation(fieldName, rule.formatMessage()));
            return;
        }
        rule.setter().accept(profile, normalized);
    }

    private static ProfileResponse toResponse(UUID userId, UserProfile profile) {
        return new ProfileResponse(
                userId,
                profile.getFirstName(),
                profile.getLastName(),
                profile.getDisplayName(),
                profile.getTimezone(),
                profile.getProfileImageUrl(),
                profile.getCreatedAt(),
                profile.getUpdatedAt(),
                profile.getVersion());
    }

    private static String normalize(String value) {
        return value == null ? null : value.trim();
    }
}