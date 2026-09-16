package com.todoapp.dto.profile;

import com.todoapp.entity.UserProfile;
import com.todoapp.validation.NotBlankOrNull;
import com.todoapp.validation.ValidHttpUrl;
import com.todoapp.validation.ValidTimezone;
import jakarta.validation.constraints.Size;

/**
 * Full replacement of the caller's profile (PUT).
 *
 * <p>All five fields are optional — the database model allows a fully empty
 * profile — but any field that <em>is</em> supplied must be valid:
 * <ul>
 *   <li>{@code null} → clear the field;</li>
 *   <li>a blank string → rejected (no accidental blank values);</li>
 *   <li>a value → length-checked against the domain/DB limits, with the
 *       timezone and image URL format-checked too.</li>
 * </ul>
 * Values are trimmed by the service layer before persistence.
 */
public record ProfileUpdateRequest(
        @Size(max = UserProfile.NAME_MAX_LENGTH,
                message = "First name must be at most 50 characters")
        @NotBlankOrNull(message = "First name must not be blank")
        String firstName,

        @Size(max = UserProfile.NAME_MAX_LENGTH,
                message = "Last name must be at most 50 characters")
        @NotBlankOrNull(message = "Last name must not be blank")
        String lastName,

        @Size(max = UserProfile.DISPLAY_NAME_MAX_LENGTH,
                message = "Display name must be at most 100 characters")
        @NotBlankOrNull(message = "Display name must not be blank")
        String displayName,

        @Size(max = UserProfile.TIMEZONE_MAX_LENGTH,
                message = "Timezone must be at most 64 characters")
        @ValidTimezone
        String timezone,

        @Size(max = UserProfile.PROFILE_IMAGE_URL_MAX_LENGTH,
                message = "Profile image URL must be at most 255 characters")
        @ValidHttpUrl
        String profileImageUrl) {
}