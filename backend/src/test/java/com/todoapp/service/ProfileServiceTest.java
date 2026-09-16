package com.todoapp.service;

import com.todoapp.dto.FieldViolation;
import com.todoapp.dto.profile.PatchField;
import com.todoapp.dto.profile.ProfilePatchRequest;
import com.todoapp.dto.profile.ProfilePatchRequestTestHelper;
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
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {

    private static final UUID USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser PRINCIPAL = new AuthenticatedUser(USER_ID, "ada");

    @Mock
    private UserProfileRepository profileRepository;
    @Mock
    private UserRepository userRepository;

    private ProfileService profileService;

    @BeforeEach
    void setUp() {
        profileService = new ProfileService(profileRepository, userRepository);
    }

    private static User user() {
        return new User("ada", "ada@example.com", "hash");
    }

    private static UserProfile profile(String firstName, String lastName, String displayName,
                                       String timezone, String imageUrl) {
        return new UserProfile(user(), firstName, lastName, displayName, timezone, imageUrl);
    }

    private static ProfilePatchRequest patch(PatchField firstName, PatchField lastName,
                                             PatchField displayName, PatchField timezone,
                                             PatchField imageUrl) {
        return ProfilePatchRequestTestHelper.of(firstName, lastName, displayName, timezone, imageUrl);
    }

    @Test
    void getProfileReturnsOnlyOwnProfileData() {
        UserProfile profile = profile("Ada", "Lovelace", "Ada L.", "Europe/London",
                "https://img.example.com/ada.png");
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        ProfileResponse response = profileService.getProfile(PRINCIPAL);

        assertThat(response.userId()).isEqualTo(USER_ID);
        assertThat(response.firstName()).isEqualTo("Ada");
        assertThat(response.lastName()).isEqualTo("Lovelace");
        assertThat(response.displayName()).isEqualTo("Ada L.");
        assertThat(response.timezone()).isEqualTo("Europe/London");
        assertThat(response.profileImageUrl()).isEqualTo("https://img.example.com/ada.png");
        assertThat(response.createdAt()).isNull();
        assertThat(response.updatedAt()).isNull();
        assertThat(response.version()).isZero();
        verify(profileRepository).findByUserId(USER_ID);
    }

    @Test
    void getProfileThrowsNotFoundWhenProfileIsAbsent() {
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> profileService.getProfile(PRINCIPAL))
                .isInstanceOf(ProfileNotFoundException.class);
    }

    @Test
    void updateProfileCreatesProfileOnFirstUse() {
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        User user = user();
        when(userRepository.getReferenceById(USER_ID)).thenReturn(user);
        when(profileRepository.saveAndFlush(any(UserProfile.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ProfileUpdateResult result = profileService.updateProfile(PRINCIPAL,
                new ProfileUpdateRequest(" Ada ", " Lovelace ", " Ada L. ", " Europe/London ",
                        " https://img.example.com/ada.png "));

        assertThat(result.created()).isTrue();
        assertThat(result.profile().userId()).isEqualTo(USER_ID);
        assertThat(result.profile().firstName()).isEqualTo("Ada");
        assertThat(result.profile().lastName()).isEqualTo("Lovelace");
        assertThat(result.profile().displayName()).isEqualTo("Ada L.");
        assertThat(result.profile().timezone()).isEqualTo("Europe/London");
        assertThat(result.profile().profileImageUrl()).isEqualTo("https://img.example.com/ada.png");

        ArgumentCaptor<UserProfile> captor = ArgumentCaptor.forClass(UserProfile.class);
        verify(profileRepository).saveAndFlush(captor.capture());
        assertThat(captor.getValue().getUser()).isSameAs(user);
        verify(userRepository).getReferenceById(USER_ID);
    }

    @Test
    void updateProfileReplacesExistingProfile() {
        UserProfile existing = profile("Old", "Name", "Old Display", "UTC", null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(profileRepository.saveAndFlush(existing)).thenReturn(existing);

        ProfileUpdateResult result = profileService.updateProfile(PRINCIPAL,
                new ProfileUpdateRequest("Ada", "Lovelace", null, "Asia/Kolkata", null));

        assertThat(result.created()).isFalse();
        assertThat(existing.getFirstName()).isEqualTo("Ada");
        assertThat(existing.getLastName()).isEqualTo("Lovelace");
        assertThat(existing.getDisplayName()).isNull();
        assertThat(existing.getTimezone()).isEqualTo("Asia/Kolkata");
        assertThat(existing.getProfileImageUrl()).isNull();
    }

    @Test
    void patchProfileAppliesOnlyProvidedFields() {
        UserProfile profile = profile("Ada", "Lovelace", "Ada L.", "Europe/London", null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));
        when(profileRepository.saveAndFlush(any(UserProfile.class))).thenAnswer(i -> i.getArgument(0));

        ProfileResponse response = profileService.patchProfile(PRINCIPAL,
                patch(PatchField.ofValue("  Grace  "), PatchField.omitted(),
                        PatchField.omitted(), PatchField.omitted(), PatchField.omitted()));

        assertThat(response.firstName()).isEqualTo("Grace");
        assertThat(profile.getLastName()).isEqualTo("Lovelace");
        assertThat(profile.getDisplayName()).isEqualTo("Ada L.");
        assertThat(profile.getTimezone()).isEqualTo("Europe/London");
        assertThat(profile.getProfileImageUrl()).isNull();
    }

    @Test
    void patchProfileClearsFieldWithExplicitNull() {
        UserProfile profile = profile("Ada", "Lovelace", "Ada L.", "Europe/London", null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));
        when(profileRepository.saveAndFlush(any(UserProfile.class))).thenAnswer(i -> i.getArgument(0));

        profileService.patchProfile(PRINCIPAL,
                patch(PatchField.ofNull(), PatchField.omitted(),
                        PatchField.omitted(), PatchField.omitted(), PatchField.omitted()));

        assertThat(profile.getFirstName()).isNull();
        assertThat(profile.getLastName()).isEqualTo("Lovelace");
    }

    @Test
    void patchProfileRejectsInvalidTimezoneWithFieldViolation() {
        UserProfile profile = profile(null, null, null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL,
                patch(PatchField.omitted(), PatchField.omitted(), PatchField.omitted(),
                        PatchField.ofValue("Banana/Island"), PatchField.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("timezone"));

        verify(profileRepository, never()).saveAndFlush(any());
    }

    @Test
    void patchProfileRejectsBlankProvidedValue() {
        UserProfile profile = profile(null, null, null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL,
                patch(PatchField.ofValue("   "), PatchField.omitted(), PatchField.omitted(),
                        PatchField.omitted(), PatchField.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("firstName"));
    }

    @Test
    void patchProfileRejectsOverLengthValue() {
        String tooLong = "x".repeat(UserProfile.DISPLAY_NAME_MAX_LENGTH + 1);
        UserProfile profile = profile(null, null, null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL,
                patch(PatchField.omitted(), PatchField.omitted(), PatchField.ofValue(tooLong),
                        PatchField.omitted(), PatchField.omitted())))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("displayName"));
    }

    @Test
    void patchProfileRejectsRelativeOrNonHttpUrls() {
        UserProfile profile = profile(null, null, null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL,
                patch(PatchField.omitted(), PatchField.omitted(), PatchField.omitted(),
                        PatchField.omitted(), PatchField.ofValue("/img/ada.png"))))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("profileImageUrl"));
    }

    @Test
    void patchProfileRejectsJavascriptUrl() {
        UserProfile profile = profile(null, null, null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(profile));

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL,
                patch(PatchField.omitted(), PatchField.omitted(), PatchField.omitted(),
                        PatchField.omitted(), PatchField.ofValue("javascript:alert(1)"))))
                .isInstanceOf(FieldValidationException.class)
                .satisfies(ex -> assertThat(((FieldValidationException) ex).getViolations())
                        .extracting(FieldViolation::field)
                        .containsExactly("profileImageUrl"));
    }

    @Test
    void patchProfileThrowsNotFoundWhenProfileIsAbsent() {
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> profileService.patchProfile(PRINCIPAL, patch(
                PatchField.omitted(), PatchField.omitted(), PatchField.omitted(),
                PatchField.omitted(), PatchField.omitted())))
                .isInstanceOf(ProfileNotFoundException.class);
    }

    @Test
    void updateProfilePropagatesOptimisticLockConflict() {
        UserProfile existing = profile("Ada", "Lovelace", null, null, null);
        when(profileRepository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(profileRepository.saveAndFlush(existing))
                .thenThrow(new ObjectOptimisticLockingFailureException(UserProfile.class, USER_ID));

        assertThatThrownBy(() -> profileService.updateProfile(PRINCIPAL,
                new ProfileUpdateRequest("Grace", "Hopper", null, null, null)))
                .isInstanceOf(ObjectOptimisticLockingFailureException.class);
    }
}