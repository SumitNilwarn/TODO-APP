package com.todoapp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.auth.LoginRequest;
import com.todoapp.dto.auth.RegisterRequest;
import com.todoapp.dto.auth.TokenResponse;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.User;
import com.todoapp.entity.UserProfile;
import com.todoapp.repository.UserProfileRepository;
import com.todoapp.repository.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end profile API tests over the real security filter chain and a real
 * PostgreSQL container (Flyway V1-V4 + Hibernate validate). Each test is
 * transactional: HTTP requests join the test transaction and rows never leak
 * between tests.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ProfileApiIT {

    private static final String PASSWORD = "S3cure-pass-42!";

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserProfileRepository userProfileRepository;

    private String register(String username) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(username, username + "@example.com", PASSWORD))))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).path("data").path("userId").asText();
    }

    private TokenResponse login(String username) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(username, PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.treeToValue(
                objectMapper.readTree(result.getResponse().getContentAsString()).path("data"),
                TokenResponse.class);
    }

    private static void setStatus(User user, AccountStatus status) {
        user.setAccountStatus(status);
    }

    private String fullProfile() {
        return """
                {"firstName":"Ada","lastName":"Lovelace","displayName":"Ada L.",
                 "timezone":"Europe/London","profileImageUrl":"https://img.example.com/ada.png"}""";
    }

    @Test
    void getWithoutProfileReturnsNotFound() throws Exception {
        String userId = register("ada-getless");
        TokenResponse tokens = login("ada-getless");

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("PROFILE_NOT_FOUND"));
    }

    @Test
    void putCreatesProfileThenGetReturnsOwnProfile() throws Exception {
        register("ada-put");
        TokenResponse tokens = login("ada-put");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("Profile created"))
                .andExpect(jsonPath("$.data.firstName").value("Ada"))
                .andExpect(jsonPath("$.data.lastName").value("Lovelace"))
                .andExpect(jsonPath("$.data.displayName").value("Ada L."))
                .andExpect(jsonPath("$.data.timezone").value("Europe/London"))
                .andExpect(jsonPath("$.data.profileImageUrl").value("https://img.example.com/ada.png"))
                .andExpect(jsonPath("$.data.version").value(0))
                .andExpect(jsonPath("$.data.createdAt").isNotEmpty())
                .andExpect(jsonPath("$.data.updatedAt").isNotEmpty());

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.firstName").value("Ada"))
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.data.username").doesNotExist())
                .andExpect(jsonPath("$.data.email").doesNotExist());
    }

    @Test
    void putReplacesAndBumpsVersionAndUpdatedAt() throws Exception {
        register("ada-replace");
        TokenResponse tokens = login("ada-replace");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        MvcResult second = mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"Grace","lastName":null,"displayName":"Grace H.",
                                 "timezone":"UTC","profileImageUrl":null}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Profile updated"))
                .andExpect(jsonPath("$.data.firstName").value("Grace"))
                .andExpect(jsonPath("$.data.lastName").value(nullValue()))
                .andExpect(jsonPath("$.data.profileImageUrl").value(nullValue()))
                .andExpect(jsonPath("$.data.version").value(1))
                .andReturn();

        JsonNode data = objectMapper.readTree(second.getResponse().getContentAsString()).path("data");
        assertThat(data.get("createdAt").asText()).isNotBlank();
        assertThat(data.get("updatedAt").asText()).isNotBlank();
    }

    @Test
    void patchUpdatesOnlyProvidedFields() throws Exception {
        register("ada-patch");
        TokenResponse tokens = login("ada-patch");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lastName\":\"Hopper\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.firstName").value("Ada"))
                .andExpect(jsonPath("$.data.lastName").value("Hopper"))
                .andExpect(jsonPath("$.data.displayName").value("Ada L."))
                .andExpect(jsonPath("$.data.timezone").value("Europe/London"));
    }

    @Test
    void patchExplicitNullClearsFieldAndOmittedKeepsValue() throws Exception {
        register("ada-clear");
        TokenResponse tokens = login("ada-clear");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.firstName").value(nullValue()))
                .andExpect(jsonPath("$.data.lastName").value("Lovelace"))
                .andExpect(jsonPath("$.data.displayName").value("Ada L."));
    }

    @Test
    void patchWithEmptyObjectIsNoop() throws Exception {
        register("ada-noop");
        TokenResponse tokens = login("ada-noop");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.firstName").value("Ada"))
                .andExpect(jsonPath("$.data.lastName").value("Lovelace"))
                .andExpect(jsonPath("$.data.timezone").value("Europe/London"));
    }

    @Test
    void patchWithoutExistingProfileReturnsNotFound() throws Exception {
        register("ada-patchless");
        TokenResponse tokens = login("ada-patchless");

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Ada\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("PROFILE_NOT_FOUND"));
    }

    @Test
    void unauthenticatedRequestsAreRejectedWith401() throws Exception {
        mockMvc.perform(get("/api/v1/profile"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(put("/api/v1/profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(patch("/api/v1/profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Ada\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void disabledAccountCannotAccessProfile() throws Exception {
        register("ada-disabled");
        TokenResponse tokens = login("ada-disabled");
        setStatus(userRepository.findByUsername("ada-disabled").orElseThrow(), AccountStatus.DISABLED);
        userRepository.flush();

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void lockedAccountCannotAccessProfile() throws Exception {
        register("ada-locked");
        TokenResponse tokens = login("ada-locked");
        setStatus(userRepository.findByUsername("ada-locked").orElseThrow(), AccountStatus.LOCKED);
        userRepository.flush();

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void userACannotSeeOrModifyUserBProfile() throws Exception {
        String aId = register("user-a");
        String bId = register("user-b");
        TokenResponse aTokens = login("user-a");
        TokenResponse bTokens = login("user-b");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + bTokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + aTokens.accessToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("PROFILE_NOT_FOUND"));

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + aTokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Intruder\"}"))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/v1/profile").header("Authorization", "Bearer " + bTokens.accessToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.firstName").value("Ada"));
    }

    @Test
    void profileIdentityAlwaysComesFromTokenNotBody() throws Exception {
        String aId = register("user-x");
        String bId = register("user-y");
        TokenResponse aTokens = login("user-x");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + aTokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Owner-Still-Me\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.userId").value(aId))
                .andExpect(jsonPath("$.data.firstName").value("Owner-Still-Me"))
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist());

        UserProfile profile = userProfileRepository.findByUserId(UUID.fromString(aId)).orElseThrow();
        assertThat(profile.getUser().getId()).isEqualTo(UUID.fromString(aId));
        assertThat(profile.getUser().getUsername()).isEqualTo("user-x");
        assertThat(userProfileRepository.findByUserId(UUID.fromString(bId))).isEmpty();
    }

    @Test
    void unknownFieldsInProfileBodyAreIgnoredNotTrusted() throws Exception {
        String aId = register("user-x");
        String bId = register("user-y");
        TokenResponse aTokens = login("user-x");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + aTokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"" + bId + "\",\"firstName\":\"Trying\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.userId").value(aId))
                .andExpect(jsonPath("$.data.firstName").value("Trying"));

        assertThat(userProfileRepository.findByUserId(UUID.fromString(aId))).isPresent();
        assertThat(userProfileRepository.findByUserId(UUID.fromString(bId))).isEmpty();
    }

    @Test
    void putValidationFailuresReturnApiErrorEnvelope() throws Exception {
        register("ada-invalid");
        TokenResponse tokens = login("ada-invalid");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"   ","lastName":"Name","displayName":" D ",
                                 "timezone":"Banana/Island","profileImageUrl":"not-a-url"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='firstName')]").exists())
                .andExpect(jsonPath("$.error.details[?(@.field=='timezone')]").exists())
                .andExpect(jsonPath("$.error.details[?(@.field=='profileImageUrl')]").exists());

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"" + "x".repeat(51) + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='firstName')]").exists());
    }

    @Test
    void patchValidationFailuresReturnApiErrorEnvelope() throws Exception {
        register("ada-patch-invalid");
        TokenResponse tokens = login("ada-patch-invalid");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"timezone\":\"Not/AZone\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='timezone')]").exists());
    }

    @Test
    void profileDataPersistsWithAuditingAndVersioning() throws Exception {
        String userId = register("ada-persist");
        TokenResponse tokens = login("ada-persist");

        mockMvc.perform(put("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullProfile()))
                .andExpect(status().isCreated());

        UserProfile profile = userProfileRepository.findByUserId(UUID.fromString(userId)).orElseThrow();
        assertThat(profile.getFirstName()).isEqualTo("Ada");
        assertThat(profile.getTimezone()).isEqualTo("Europe/London");
        assertThat(profile.getCreatedAt()).isNotNull();
        assertThat(profile.getUpdatedAt()).isNotNull();
        assertThat(profile.getVersion()).isZero();

        java.time.Instant updatedAtBeforePatch = profile.getUpdatedAt();

        mockMvc.perform(patch("/api/v1/profile")
                        .header("Authorization", "Bearer " + tokens.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"firstName\":\"Grace\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.firstName").value("Grace"))
                .andExpect(jsonPath("$.data.version").value(1));

        UserProfile updated = userProfileRepository.findByUserId(UUID.fromString(userId)).orElseThrow();
        assertThat(updated.getFirstName()).isEqualTo("Grace");
        assertThat(updated.getVersion()).isEqualTo(1);
        assertThat(updated.getUpdatedAt()).isAfter(updatedAtBeforePatch);
    }
}