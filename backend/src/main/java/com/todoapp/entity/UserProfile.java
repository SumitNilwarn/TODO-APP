package com.todoapp.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.ForeignKey;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

/**
 * Optional profile information for a {@link User}.
 *
 * <p>Kept as a separate aggregate so account/security data is never mixed with
 * profile data. A {@code user_id} foreign key plus a unique constraint enforce
 * exactly one profile per user. The owning side of the one-to-one relationship
 * is {@link UserProfile}; {@code User} has no back-reference (no accidental
 * eager loading, and profile lookups go through {@code UserProfileRepository}).</p>
 */
@Entity
@Table(name = "user_profiles")
public class UserProfile extends BaseEntity {

    public static final int NAME_MAX_LENGTH = 50;
    public static final int DISPLAY_NAME_MAX_LENGTH = 100;
    public static final int TIMEZONE_MAX_LENGTH = 64;
    public static final int PROFILE_IMAGE_URL_MAX_LENGTH = 255;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true,
            foreignKey = @ForeignKey(name = "fk_user_profiles_user"))
    private User user;

    @Column(name = "first_name", length = NAME_MAX_LENGTH)
    private String firstName;

    @Column(name = "last_name", length = NAME_MAX_LENGTH)
    private String lastName;

    @Column(name = "display_name", length = DISPLAY_NAME_MAX_LENGTH)
    private String displayName;

    @Column(name = "timezone", length = TIMEZONE_MAX_LENGTH)
    private String timezone;

    @Column(name = "profile_image_url", length = PROFILE_IMAGE_URL_MAX_LENGTH)
    private String profileImageUrl;

    protected UserProfile() {
    }

    public UserProfile(User user, String firstName, String lastName,
                       String displayName, String timezone, String profileImageUrl) {
        this.user = user;
        this.firstName = firstName;
        this.lastName = lastName;
        this.displayName = displayName;
        this.timezone = timezone;
        this.profileImageUrl = profileImageUrl;
    }

    public User getUser() {
        return user;
    }

    public String getFirstName() {
        return firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getTimezone() {
        return timezone;
    }

    public String getProfileImageUrl() {
        return profileImageUrl;
    }

    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }

    public void setLastName(String lastName) {
        this.lastName = lastName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public void setTimezone(String timezone) {
        this.timezone = timezone;
    }

    public void setProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }
}