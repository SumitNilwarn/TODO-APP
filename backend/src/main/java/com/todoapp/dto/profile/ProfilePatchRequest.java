package com.todoapp.dto.profile;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

/**
 * Partial update of the caller's profile (PATCH).
 *
 * <p>Each field is a {@link PatchField} that distinguishes three states:
 * <ul>
 *   <li>omitted → the property setter is never called, so the field stays
 *       {@link PatchField#omitted()} and the current value is left unchanged;</li>
 *   <li>explicit {@code null} → Jackson invokes the setter with {@code null},
 *       which is mapped to {@link PatchField#ofNull()} (clear the field);</li>
 *   <li>a string → {@code PatchFieldDeserializer} produces
 *       {@link PatchField#ofValue(String)} (validate, normalize and store).</li>
 * </ul>
 * The service layer validates provided values (blank/length/timezone/image-URL)
 * and throws the standard {@code VALIDATION_ERROR} envelope on violations.</p>
 */
public final class ProfilePatchRequest {

    private PatchField firstName = PatchField.omitted();
    private PatchField lastName = PatchField.omitted();
    private PatchField displayName = PatchField.omitted();
    private PatchField timezone = PatchField.omitted();
    private PatchField profileImageUrl = PatchField.omitted();

    public ProfilePatchRequest() {
    }

    private static PatchField nullToPatchField(PatchField value) {
        return value == null ? PatchField.ofNull() : value;
    }

    public PatchField firstName() {
        return firstName;
    }

    public PatchField lastName() {
        return lastName;
    }

    public PatchField displayName() {
        return displayName;
    }

    public PatchField timezone() {
        return timezone;
    }

    public PatchField profileImageUrl() {
        return profileImageUrl;
    }

    @JsonDeserialize(using = PatchFieldDeserializer.class)
    public void setFirstName(PatchField value) {
        this.firstName = nullToPatchField(value);
    }

    @JsonDeserialize(using = PatchFieldDeserializer.class)
    public void setLastName(PatchField value) {
        this.lastName = nullToPatchField(value);
    }

    @JsonDeserialize(using = PatchFieldDeserializer.class)
    public void setDisplayName(PatchField value) {
        this.displayName = nullToPatchField(value);
    }

    @JsonDeserialize(using = PatchFieldDeserializer.class)
    public void setTimezone(PatchField value) {
        this.timezone = nullToPatchField(value);
    }

    @JsonDeserialize(using = PatchFieldDeserializer.class)
    public void setProfileImageUrl(PatchField value) {
        this.profileImageUrl = nullToPatchField(value);
    }
}