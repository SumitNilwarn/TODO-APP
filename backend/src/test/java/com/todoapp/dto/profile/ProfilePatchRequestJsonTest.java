package com.todoapp.dto.profile;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Verifies that PATCH deserialization distinguishes an omitted field from an
 * explicit {@code null} — the behaviour {@link PatchField} exists to provide.
 */
class ProfilePatchRequestJsonTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void explicitNullIsProvidedNullAndMissingKeyIsOmitted() throws Exception {
        ProfilePatchRequest request = objectMapper.readValue(
                "{\"firstName\":\"Ada\",\"displayName\":null}", ProfilePatchRequest.class);

        assertThat(request.firstName().isProvided()).isTrue();
        assertThat(request.firstName().getValue()).isEqualTo("Ada");
        assertThat(request.lastName().isProvided()).isFalse();
        assertThat(request.displayName().isProvided()).isTrue();
        assertThat(request.displayName().getValue()).isNull();
        assertThat(request.timezone().isProvided()).isFalse();
        assertThat(request.profileImageUrl().isProvided()).isFalse();
    }

    @Test
    void emptyObjectMeansAllFieldsOmitted() throws Exception {
        ProfilePatchRequest request = objectMapper.readValue("{}", ProfilePatchRequest.class);

        assertThat(request.firstName().isProvided()).isFalse();
        assertThat(request.lastName().isProvided()).isFalse();
        assertThat(request.displayName().isProvided()).isFalse();
        assertThat(request.timezone().isProvided()).isFalse();
        assertThat(request.profileImageUrl().isProvided()).isFalse();
    }

    @Test
    void nonStringValuesAreRejected() {
        assertThatThrownBy(() -> objectMapper.readValue(
                "{\"firstName\":42}", ProfilePatchRequest.class))
                .isInstanceOf(Exception.class);
    }
}