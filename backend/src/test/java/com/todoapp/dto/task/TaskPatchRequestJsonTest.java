package com.todoapp.dto.task;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Verifies that task PATCH deserialization distinguishes an omitted field from
 * an explicit {@code null} — the behaviour {@link TaskPatchValue} exists to
 * provide.
 */
class TaskPatchRequestJsonTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void explicitNullIsProvidedNullAndMissingKeyIsOmitted() throws Exception {
        TaskPatchRequest request = objectMapper.readValue(
                "{\"title\":\"Ship it\",\"description\":null}", TaskPatchRequest.class);

        assertThat(request.title().isProvided()).isTrue();
        assertThat(request.title().getText()).isEqualTo("Ship it");
        assertThat(request.description().isProvided()).isTrue();
        assertThat(request.description().getText()).isNull();
        assertThat(request.status().isProvided()).isFalse();
        assertThat(request.dueDate().isProvided()).isFalse();
    }

    @Test
    void emptyObjectMeansAllFieldsOmitted() throws Exception {
        TaskPatchRequest request = objectMapper.readValue("{}", TaskPatchRequest.class);

        assertThat(request.title().isProvided()).isFalse();
        assertThat(request.description().isProvided()).isFalse();
        assertThat(request.status().isProvided()).isFalse();
        assertThat(request.dueDate().isProvided()).isFalse();
    }

    @Test
    void nonStringValuesAreRejected() {
        assertThatThrownBy(() -> objectMapper.readValue(
                "{\"title\":42}", TaskPatchRequest.class))
                .isInstanceOf(Exception.class);
    }
}