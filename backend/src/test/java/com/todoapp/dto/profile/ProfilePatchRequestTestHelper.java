package com.todoapp.dto.profile;

/**
 * Static factory that creates {@link ProfilePatchRequest} instances using
 * setters — the only way to build one for unit tests (Jackson populates the
 * real object via the setters during HTTP deserialization).
 */
public final class ProfilePatchRequestTestHelper {

    private ProfilePatchRequestTestHelper() {
    }

    public static ProfilePatchRequest of(PatchField firstName, PatchField lastName,
                                         PatchField displayName, PatchField timezone,
                                         PatchField profileImageUrl) {
        ProfilePatchRequest request = new ProfilePatchRequest();
        request.setFirstName(firstName);
        request.setLastName(lastName);
        request.setDisplayName(displayName);
        request.setTimezone(timezone);
        request.setProfileImageUrl(profileImageUrl);
        return request;
    }
}