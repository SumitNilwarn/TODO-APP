package com.todoapp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.auth.LoginRequest;
import com.todoapp.dto.auth.RegisterRequest;
import com.todoapp.dto.auth.TokenResponse;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import com.todoapp.entity.User;
import com.todoapp.repository.TaskRepository;
import com.todoapp.repository.UserRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end task API tests over the real security filter chain and a real
 * PostgreSQL 16 container (Flyway V1-V4 schema + Hibernate validate). Each test
 * is transactional: HTTP requests join the test transaction and rows never leak
 * between tests.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class TaskApiIT {

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
    private TaskRepository taskRepository;

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

    private TokenResponse registerAndLogin(String username) throws Exception {
        register(username);
        return login(username);
    }

    private static String bearer(TokenResponse tokens) {
        return "Bearer " + tokens.accessToken();
    }

    private String createTask(TokenResponse tokens, String jsonBody) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonBody))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).path("data").path("id").asText();
    }

    private Task seedTask(String username, String title, TaskStatus status,
                          LocalDate dueDate, String description) {
        User owner = userRepository.findByUsername(username).orElseThrow();
        Task task = new Task(owner, title);
        task.setDescription(description);
        task.setStatus(status);
        task.setDueDate(dueDate);
        if (status == TaskStatus.COMPLETED) {
            task.setCompletedAt(Instant.now().plusSeconds(1));
        }
        return taskRepository.saveAndFlush(task);
    }

    private static void setStatus(User user, AccountStatus status) {
        user.setAccountStatus(status);
    }

    // ------------------------------------------------------------ create

    @Test
    void postTaskWithValidJwtCreatesDefaultTask() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-create");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"  Write schema migration  \"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("Task created"))
                .andExpect(jsonPath("$.data.title").value("Write schema migration"))
                .andExpect(jsonPath("$.data.status").value("TODO"))
                .andExpect(jsonPath("$.data.description").value(nullValue()))
                .andExpect(jsonPath("$.data.dueDate").value(nullValue()))
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()))
                .andExpect(jsonPath("$.data.overdue").value(false))
                .andExpect(jsonPath("$.data.version").value(0))
                .andExpect(jsonPath("$.data.createdAt").isNotEmpty())
                .andExpect(jsonPath("$.data.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.data.userId").doesNotExist());
    }

    @Test
    void postTaskWithExplicitValidFieldsPersistsThem() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-full");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Ship v2","description":"Release notes",
                                 "status":"IN_PROGRESS","dueDate":"2026-08-01"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.title").value("Ship v2"))
                .andExpect(jsonPath("$.data.description").value("Release notes"))
                .andExpect(jsonPath("$.data.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.data.dueDate").value("2026-08-01"))
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));
    }

    @Test
    void postTaskValidationFailuresUseApiErrorEnvelope() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-invalid");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"   \"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='title')]").exists());

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"" + "x".repeat(201) + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    // ------------------------------------------------------------ get

    @Test
    void getTaskReturnsOwnTask() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-get");
        String id = createTask(tokens, "{\"title\":\"Mine\"}");

        mockMvc.perform(get("/api/v1/tasks/" + id).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(id))
                .andExpect(jsonPath("$.data.title").value("Mine"))
                .andExpect(jsonPath("$.data.status").value("TODO"));
    }

    @Test
    void getTaskForUnknownIdReturnsNotFound() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-getless");

        mockMvc.perform(get("/api/v1/tasks/" + UUID.randomUUID()).header("Authorization", bearer(tokens)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("TASK_NOT_FOUND"));
    }

    @Test
    void getTaskWithMalformedIdReturnsBadRequest() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-badid");

        mockMvc.perform(get("/api/v1/tasks/not-a-uuid").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_PARAMETER"));
    }

    // ------------------------------------------------------------ put

    @Test
    void putTaskFullyReplacesEditableFieldsAndBumpsVersion() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-put");
        String id = createTask(tokens, """
                {"title":"old","description":"old desc",
                 "status":"IN_PROGRESS","dueDate":"2026-08-01"}""");

        MvcResult updated = mockMvc.perform(put("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"new","description":null,
                                 "status":"COMPLETED","dueDate":null}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("new"))
                .andExpect(jsonPath("$.data.description").value(nullValue()))
                .andExpect(jsonPath("$.data.dueDate").value(nullValue()))
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.completedAt").isNotEmpty())
                .andExpect(jsonPath("$.data.version").value(1))
                .andReturn();

        JsonNode data = objectMapper.readTree(updated.getResponse().getContentAsString()).path("data");
        assertThat(data.get("createdAt").asText()).isNotBlank();
    }

    @Test
    void putTaskRejectsInvalidTransition() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-invalid-put");
        String id = createTask(tokens, "{\"title\":\"done\",\"status\":\"TODO\"}");
        mockMvc.perform(patch("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"reopen\",\"status\":\"TODO\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("INVALID_TRANSITION"));
    }

    // ------------------------------------------------------------ patch

    @Test
    void patchTaskUpdatesOnlyProvidedFields() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-patch");
        String id = createTask(tokens, """
                {"title":"old","description":"desc",
                 "status":"IN_PROGRESS","dueDate":"2026-08-01"}""");

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Grace\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Grace"))
                .andExpect(jsonPath("$.data.description").value("desc"))
                .andExpect(jsonPath("$.data.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.data.dueDate").value("2026-08-01"));
    }

    @Test
    void patchTaskExplicitNullClearsOptionalFieldsAndNoopOnEmptyObject() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-clear");
        String id = createTask(tokens, """
                {"title":"old","description":"desc","dueDate":"2026-08-01"}""");

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"description\":null,\"dueDate\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").value(nullValue()))
                .andExpect(jsonPath("$.data.dueDate").value(nullValue()))
                .andExpect(jsonPath("$.data.title").value("old"));

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("old"))
                .andExpect(jsonPath("$.data.status").value("TODO"));
    }

    @Test
    void patchTaskRejectsInvalidValuesWithValidationEnvelope() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-patch-invalid");
        String id = createTask(tokens, "{\"title\":\"old\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":null}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='title')]").exists());

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dueDate\":\"2026-13-45\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='dueDate')]").exists());

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"NOT_A_STATUS\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='status')]").exists());
    }

    // ------------------------------------------------------------ delete

    @Test
    void deleteTaskDeletesOwnTask() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-delete");
        String id = createTask(tokens, "{\"title\":\"bye\"}");

        mockMvc.perform(delete("/api/v1/tasks/" + id).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("Task deleted"));

        mockMvc.perform(get("/api/v1/tasks/" + id).header("Authorization", bearer(tokens)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("TASK_NOT_FOUND"));
    }

    // ------------------------------------------------------------ status/complete/cancel

    @Test
    void patchStatusEndpointChangesStatus() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-status");
        String id = createTask(tokens, "{\"title\":\"wip\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/status")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"IN_PROGRESS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));
    }

    @Test
    void completeEndpointMarksTaskCompletedWithServerCompletedAt() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-complete");
        String id = createTask(tokens, "{\"title\":\"finish\",\"status\":\"IN_PROGRESS\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.completedAt").isNotEmpty())
                .andExpect(jsonPath("$.data.overdue").value(false));
    }

    @Test
    void cancelEndpointMarksTaskCancelledAndClearsCompletedAt() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-cancel");
        String id = createTask(tokens, "{\"title\":\"drop it\",\"status\":\"IN_PROGRESS\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/cancel")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CANCELLED"))
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));
    }

    @Test
    void invalidTransitionsAreRejectedWith409() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-terminal");
        String completedId = createTask(tokens, "{\"title\":\"done\"}");
        mockMvc.perform(patch("/api/v1/tasks/" + completedId + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk());

        mockMvc.perform(patch("/api/v1/tasks/" + completedId + "/status")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"IN_PROGRESS\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("INVALID_TRANSITION"));

        mockMvc.perform(patch("/api/v1/tasks/" + completedId + "/cancel")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("INVALID_TRANSITION"));

        String cancelledId = createTask(tokens, "{\"title\":\"cancelled\"}");
        mockMvc.perform(patch("/api/v1/tasks/" + cancelledId + "/cancel")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk());
        mockMvc.perform(patch("/api/v1/tasks/" + cancelledId + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("INVALID_TRANSITION"));
    }

    @Test
    void completedAtCannotBeClientForged() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-forge");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"forge default","completedAt":"2030-01-01T00:00:00Z"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.status").value("TODO"))
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"forge complete","status":"COMPLETED",
                                 "completedAt":"2030-01-01T00:00:00Z"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.completedAt").value(
                        org.hamcrest.Matchers.not("2030-01-01T00:00:00Z")));
    }

    @Test
    void completedTasksHaveCompletedAtAndNonCompletedDoNotRetainIt() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-behaviour");
        String inProgressId = createTask(tokens, "{\"title\":\"running\",\"status\":\"IN_PROGRESS\"}");

        mockMvc.perform(get("/api/v1/tasks/" + inProgressId).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));

        mockMvc.perform(patch("/api/v1/tasks/" + inProgressId + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.completedAt").isNotEmpty());
    }

    @Test
    void cancelledTasksDoNotHaveCompletedAt() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-cancelled-clear");
        String id = createTask(tokens, "{\"title\":\"cancel me\",\"status\":\"IN_PROGRESS\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/cancel")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.completedAt").value(nullValue()));

        Task task = taskRepository.findById(UUID.fromString(id)).orElseThrow();
        assertThat(task.getCompletedAt()).isNull();
    }

    // ------------------------------------------------------------ list

    @Test
    void getTasksListsOnlyOwnTasks() throws Exception {
        TokenResponse a = registerAndLogin("list-user-a");
        TokenResponse b = registerAndLogin("list-user-b");
        createTask(a, "{\"title\":\"A one\"}");
        createTask(a, "{\"title\":\"A two\"}");
        createTask(b, "{\"title\":\"B only\"}");

        mockMvc.perform(get("/api/v1/tasks").header("Authorization", bearer(a)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.content.length()").value(2))
                .andExpect(jsonPath("$.data.content[?(@.title=='A one')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='A two')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='B only')]").doesNotExist())
                .andExpect(jsonPath("$.data.page").value(0))
                .andExpect(jsonPath("$.data.size").value(20))
                .andExpect(jsonPath("$.data.totalElements").value(2))
                .andExpect(jsonPath("$.data.totalPages").value(1))
                .andExpect(jsonPath("$.data.first").value(true))
                .andExpect(jsonPath("$.data.last").value(true));

        mockMvc.perform(get("/api/v1/tasks").header("Authorization", bearer(b)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("B only"));
    }

    @Test
    void getTasksWithoutQueryParametersUsesDocumentedDefaults() throws Exception {
        TokenResponse tokens = registerAndLogin("list-defaults");
        createTask(tokens, "{\"title\":\"latest\"}");
        createTask(tokens, "{\"title\":\"older\",\"status\":\"COMPLETED\"}");

        mockMvc.perform(get("/api/v1/tasks").header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.page").value(0))
                .andExpect(jsonPath("$.data.size").value(20))
                .andExpect(jsonPath("$.data.totalElements").value(2))
                .andExpect(jsonPath("$.data.totalPages").value(1))
                .andExpect(jsonPath("$.data.first").value(true))
                .andExpect(jsonPath("$.data.last").value(true))
                .andExpect(jsonPath("$.data.content[0].overdue").exists());
    }

    // ------------------------------------------------------------ ownership

    @Test
    void userACannotReadModifyDeleteOrCompleteUserBTask() throws Exception {
        String aId = register("user-a-acc");
        String bId = register("user-b-acc");
        TokenResponse aTokens = login("user-a-acc");
        TokenResponse bTokens = login("user-b-acc");
        String bTaskId = createTask(bTokens, "{\"title\":\"B secret\"}");

        mockMvc.perform(get("/api/v1/tasks/" + bTaskId).header("Authorization", bearer(aTokens)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("TASK_NOT_FOUND"));

        mockMvc.perform(put("/api/v1/tasks/" + bTaskId)
                        .header("Authorization", bearer(aTokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"stolen\",\"status\":\"TODO\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("TASK_NOT_FOUND"));

        mockMvc.perform(patch("/api/v1/tasks/" + bTaskId)
                        .header("Authorization", bearer(aTokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"tampered\"}"))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete("/api/v1/tasks/" + bTaskId).header("Authorization", bearer(aTokens)))
                .andExpect(status().isNotFound());

        mockMvc.perform(patch("/api/v1/tasks/" + bTaskId + "/complete")
                        .header("Authorization", bearer(aTokens)))
                .andExpect(status().isNotFound());

        mockMvc.perform(patch("/api/v1/tasks/" + bTaskId + "/cancel")
                        .header("Authorization", bearer(aTokens)))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/v1/tasks").header("Authorization", bearer(aTokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(0));

        mockMvc.perform(get("/api/v1/tasks/" + bTaskId).header("Authorization", bearer(bTokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("B secret"));
    }

    @Test
    void spoofedUserIdInPayloadNeverChangesOwnership() throws Exception {
        String aId = register("spoof-a");
        String bId = register("spoof-b");
        TokenResponse aTokens = login("spoof-a");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(aTokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"stays mine\",\"userId\":\"" + bId + "\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.title").value("stays mine"))
                .andExpect(jsonPath("$.data.userId").doesNotExist());

        assertThat(taskRepository.findByUserId(UUID.fromString(aId)))
                .extracting(Task::getTitle)
                .containsExactly("stays mine");
        assertThat(taskRepository.findByUserId(UUID.fromString(bId))).isEmpty();
    }

    // ------------------------------------------------------------ advanced listing / filters

    @Test
    void statusFilterReturnsOnlyMatchingTasks() throws Exception {
        TokenResponse tokens = registerAndLogin("q-status");
        seedTask("q-status", "t1", TaskStatus.TODO, null, null);
        seedTask("q-status", "t2", TaskStatus.IN_PROGRESS, null, null);
        seedTask("q-status", "t3", TaskStatus.IN_PROGRESS, null, null);
        seedTask("q-status", "t4", TaskStatus.COMPLETED, null, null);
        seedTask("q-status", "t5", TaskStatus.CANCELLED, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("status", "IN_PROGRESS")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(2))
                .andExpect(jsonPath("$.data.content[0].status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.data.content[1].status").value("IN_PROGRESS"));

        mockMvc.perform(get("/api/v1/tasks").param("status", "TODO")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("t1"));
    }

    @Test
    void dueDateRangeIsInclusiveAndExcludesNullDueDates() throws Exception {
        TokenResponse tokens = registerAndLogin("q-dates");
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seedTask("q-dates", "past", TaskStatus.TODO, today.minusDays(2), null);
        seedTask("q-dates", "from", TaskStatus.TODO, today, null);
        seedTask("q-dates", "between", TaskStatus.TODO, today.plusDays(1), null);
        seedTask("q-dates", "to", TaskStatus.TODO, today.plusDays(2), null);
        seedTask("q-dates", "future", TaskStatus.TODO, today.plusDays(5), null);
        seedTask("q-dates", "nodue", TaskStatus.TODO, null, null);

        mockMvc.perform(get("/api/v1/tasks")
                        .param("dueDateFrom", today.toString())
                        .param("dueDateTo", today.plusDays(2).toString())
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(3))
                .andExpect(jsonPath("$.data.content[?(@.title=='from')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='to')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='past')]").doesNotExist())
                .andExpect(jsonPath("$.data.content[?(@.title=='nodue')]").doesNotExist());
    }

    @Test
    void searchMatchesTitleAndDescriptionCaseInsensitively() throws Exception {
        TokenResponse tokens = registerAndLogin("q-search");
        seedTask("q-search", "Write the audit report", TaskStatus.TODO, null, "finance docs");
        seedTask("q-search", "PAINT THE FENCE", TaskStatus.TODO, null, null);
        seedTask("q-search", "Groceries", TaskStatus.TODO, null, "review the auth flow notes");

        mockMvc.perform(get("/api/v1/tasks").param("search", "repOrt")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("Write the audit report"));

        mockMvc.perform(get("/api/v1/tasks").param("search", "AUTH")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("Groceries"));

        mockMvc.perform(get("/api/v1/tasks").param("search", "  fence  ")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("PAINT THE FENCE"));
    }

    @Test
    void blankSearchActsAsNoFilter() throws Exception {
        TokenResponse tokens = registerAndLogin("q-blanksearch");
        seedTask("q-blanksearch", "a", TaskStatus.TODO, null, null);
        seedTask("q-blanksearch", "b", TaskStatus.TODO, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("search", "   ")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(2));
    }

    @Test
    void searchEscapesLikeWildcards() throws Exception {
        TokenResponse tokens = registerAndLogin("q-escape");
        seedTask("q-escape", "progress at 50%", TaskStatus.TODO, null, null);
        seedTask("q-escape", "under_score", TaskStatus.TODO, null, null);
        seedTask("q-escape", "plain progress", TaskStatus.TODO, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("search", "50%")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("progress at 50%"));

        mockMvc.perform(get("/api/v1/tasks").param("search", "under_score")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("under_score"));
    }

    @Test
    void paginationReturnsCorrectSlicesAndMetadata() throws Exception {
        TokenResponse tokens = registerAndLogin("q-pages");
        for (int i = 0; i < 25; i++) {
            seedTask("q-pages", "task " + i, TaskStatus.TODO, null, null);
        }

        mockMvc.perform(get("/api/v1/tasks").param("page", "0").param("size", "10")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.page").value(0))
                .andExpect(jsonPath("$.data.content.length()").value(10))
                .andExpect(jsonPath("$.data.totalElements").value(25))
                .andExpect(jsonPath("$.data.totalPages").value(3))
                .andExpect(jsonPath("$.data.first").value(true))
                .andExpect(jsonPath("$.data.last").value(false));

        mockMvc.perform(get("/api/v1/tasks").param("page", "1").param("size", "10")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.page").value(1))
                .andExpect(jsonPath("$.data.content.length()").value(10))
                .andExpect(jsonPath("$.data.first").value(false))
                .andExpect(jsonPath("$.data.last").value(false));

        mockMvc.perform(get("/api/v1/tasks").param("page", "2").param("size", "10")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.page").value(2))
                .andExpect(jsonPath("$.data.content.length()").value(5))
                .andExpect(jsonPath("$.data.last").value(true));

        mockMvc.perform(get("/api/v1/tasks").param("page", "3").param("size", "10")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(0))
                .andExpect(jsonPath("$.data.totalPages").value(3));
    }

    @Test
    void sortingByTitleAscendingAndDescending() throws Exception {
        TokenResponse tokens = registerAndLogin("q-sort");
        seedTask("q-sort", "banana", TaskStatus.TODO, null, null);
        seedTask("q-sort", "apple", TaskStatus.TODO, null, null);
        seedTask("q-sort", "cherry", TaskStatus.TODO, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("sort", "title").param("direction", "ASC")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].title").value("apple"))
                .andExpect(jsonPath("$.data.content[1].title").value("banana"))
                .andExpect(jsonPath("$.data.content[2].title").value("cherry"));

        mockMvc.perform(get("/api/v1/tasks").param("sort", "title").param("direction", "DESC")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].title").value("cherry"))
                .andExpect(jsonPath("$.data.content[2].title").value("apple"));
    }

    @Test
    void sortingByDueDateAscending() throws Exception {
        TokenResponse tokens = registerAndLogin("q-sort-date");
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seedTask("q-sort-date", "later", TaskStatus.TODO, today.plusDays(3), null);
        seedTask("q-sort-date", "sooner", TaskStatus.TODO, today.plusDays(1), null);
        seedTask("q-sort-date", "middle", TaskStatus.TODO, today.plusDays(2), null);

        mockMvc.perform(get("/api/v1/tasks").param("sort", "dueDate").param("direction", "ASC")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].title").value("sooner"))
                .andExpect(jsonPath("$.data.content[1].title").value("middle"))
                .andExpect(jsonPath("$.data.content[2].title").value("later"));
    }

    @Test
    void sortingByStatusUsesAllowlistedField() throws Exception {
        TokenResponse tokens = registerAndLogin("q-sort-status");
        seedTask("q-sort-status", "todo", TaskStatus.TODO, null, null);
        seedTask("q-sort-status", "cancelled", TaskStatus.CANCELLED, null, null);
        seedTask("q-sort-status", "completed", TaskStatus.COMPLETED, null, null);
        seedTask("q-sort-status", "progress", TaskStatus.IN_PROGRESS, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("sort", "status").param("direction", "ASC")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].title").value("cancelled"))
                .andExpect(jsonPath("$.data.content[1].title").value("completed"))
                .andExpect(jsonPath("$.data.content[2].title").value("progress"))
                .andExpect(jsonPath("$.data.content[3].title").value("todo"));
    }

    @Test
    void overdueFilterDistinguishesOverdueAndCompletedOrCancelled() throws Exception {
        TokenResponse tokens = registerAndLogin("q-overdue");
        LocalDate yesterday = LocalDate.now(ZoneOffset.UTC).minusDays(1);
        seedTask("q-overdue", "overdue-todo", TaskStatus.TODO, yesterday, null);
        seedTask("q-overdue", "overdue-progress", TaskStatus.IN_PROGRESS, yesterday, null);
        seedTask("q-overdue", "completed-past", TaskStatus.COMPLETED, yesterday, null);
        seedTask("q-overdue", "cancelled-past", TaskStatus.CANCELLED, yesterday, null);
        seedTask("q-overdue", "future", TaskStatus.TODO, LocalDate.now(ZoneOffset.UTC).plusDays(2), null);
        seedTask("q-overdue", "no-due", TaskStatus.TODO, null, null);

        mockMvc.perform(get("/api/v1/tasks").param("overdue", "true")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(2))
                .andExpect(jsonPath("$.data.content[?(@.title=='overdue-todo')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='overdue-progress')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='completed-past')]").doesNotExist())
                .andExpect(jsonPath("$.data.content[?(@.title=='cancelled-past')]").doesNotExist());

        mockMvc.perform(get("/api/v1/tasks").param("overdue", "false")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(4))
                .andExpect(jsonPath("$.data.content[?(@.title=='overdue-todo')]").doesNotExist())
                .andExpect(jsonPath("$.data.content[?(@.title=='overdue-progress')]").doesNotExist())
                .andExpect(jsonPath("$.data.content[?(@.title=='completed-past')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='cancelled-past')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='future')]").exists())
                .andExpect(jsonPath("$.data.content[?(@.title=='no-due')]").exists());
    }

    @Test
    void invalidPaginationRejectedWithValidationError() throws Exception {
        TokenResponse tokens = registerAndLogin("q-invalid1");
        mockMvc.perform(get("/api/v1/tasks").param("page", "-1").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[0].field").value("page"));
        mockMvc.perform(get("/api/v1/tasks").param("page", "x").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("page"));
        mockMvc.perform(get("/api/v1/tasks").param("size", "0").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("size"));
        mockMvc.perform(get("/api/v1/tasks").param("size", "x").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("size"));
        mockMvc.perform(get("/api/v1/tasks").param("size", "1000").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("size"));
    }

    @Test
    void invalidSortDirectionStatusAndOverdueRejected() throws Exception {
        TokenResponse tokens = registerAndLogin("q-invalid2");
        mockMvc.perform(get("/api/v1/tasks").param("sort", "userId").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("sort"));
        mockMvc.perform(get("/api/v1/tasks").param("sort", "overdue").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("sort"));
        mockMvc.perform(get("/api/v1/tasks").param("direction", "UP").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("direction"));
        mockMvc.perform(get("/api/v1/tasks").param("status", "OVERDUE").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("status"));
        mockMvc.perform(get("/api/v1/tasks").param("status", "WIP").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("status"));
        mockMvc.perform(get("/api/v1/tasks").param("overdue", "yes").header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("overdue"));
    }

    @Test
    void invalidDatesAndReversedRangeRejected() throws Exception {
        TokenResponse tokens = registerAndLogin("q-invalid3");
        mockMvc.perform(get("/api/v1/tasks").param("dueDateFrom", "01-08-2026")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("dueDateFrom"));
        mockMvc.perform(get("/api/v1/tasks")
                        .param("dueDateFrom", "2026-08-02")
                        .param("dueDateTo", "2026-08-01")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.details[0].field").value("dueDateFrom"));
    }

    @Test
    void queryParametersNeverLeakAnotherUsersTasks() throws Exception {
        TokenResponse a = registerAndLogin("q-own-a");
        TokenResponse b = registerAndLogin("q-own-b");
        seedTask("q-own-a", "shared-title", TaskStatus.TODO, LocalDate.now(ZoneOffset.UTC).minusDays(1), "secret-a");
        seedTask("q-own-b", "shared-title", TaskStatus.TODO, LocalDate.now(ZoneOffset.UTC).minusDays(2), "secret-b");

        mockMvc.perform(get("/api/v1/tasks").param("search", "shared-title")
                        .header("Authorization", bearer(a)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].description").value("secret-a"));

        mockMvc.perform(get("/api/v1/tasks").param("overdue", "true")
                        .header("Authorization", bearer(b)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].description").value("secret-b"));
    }

    // ------------------------------------------------------------ auth / accounts

    @Test
    void unauthenticatedRequestsAreRejectedWith401() throws Exception {
        mockMvc.perform(get("/api/v1/tasks"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(post("/api/v1/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(get("/api/v1/tasks/" + UUID.randomUUID()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void disabledAccountCannotAccessTasks() throws Exception {
        register("ada-disabled-tasks");
        TokenResponse tokens = login("ada-disabled-tasks");
        setStatus(userRepository.findByUsername("ada-disabled-tasks").orElseThrow(), AccountStatus.DISABLED);
        userRepository.flush();

        mockMvc.perform(get("/api/v1/tasks").header("Authorization", bearer(tokens)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void lockedAccountCannotAccessTasks() throws Exception {
        register("ada-locked-tasks");
        TokenResponse tokens = login("ada-locked-tasks");
        setStatus(userRepository.findByUsername("ada-locked-tasks").orElseThrow(), AccountStatus.LOCKED);
        userRepository.flush();

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"nope\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    // ------------------------------------------------------------ overdue

    @Test
    void completeEndpointCanTransitionFromTodo() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-complete-todo");
        String id = createTask(tokens, "{\"title\":\"TODO task\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.completedAt").isNotEmpty())
                .andExpect(jsonPath("$.data.overdue").value(false));
    }

    @Test
    void cancelEndpointCanTransitionFromTodo() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-cancel-todo");
        String id = createTask(tokens, "{\"title\":\"TODO to cancel\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/cancel")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CANCELLED"))
                .andExpect(jsonPath("$.data.overdue").value(false));
    }

    @Test
    void patchTaskRejectsBlankDescription() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-patch-blank-desc");
        String id = createTask(tokens, "{\"title\":\"Has desc\",\"description\":\"Keep me\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"description\":\"   \"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='description')]").exists());
    }

    @Test
    void taskDueTodayIsNotOverdue() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-today-overdue");
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        LocalDate yesterday = today.minusDays(1);

        String todayId = createTask(tokens, "{\"title\":\"Due today\",\"dueDate\":\"" + today + "\"}");
        mockMvc.perform(get("/api/v1/tasks/" + todayId).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overdue").value(false));

        String yesterdayId = createTask(tokens, "{\"title\":\"Due yesterday\",\"dueDate\":\"" + yesterday + "\"}");
        mockMvc.perform(get("/api/v1/tasks/" + yesterdayId).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overdue").value(true));
    }

    @Test
    void searchEscapesBackslashCharacter() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-backslash-search");
        seedTask("ada-backslash-search", "path\\to\\file", TaskStatus.TODO, null, "A file path");
        seedTask("ada-backslash-search", "other task", TaskStatus.TODO, null, "No backslash");

        mockMvc.perform(get("/api/v1/tasks").param("search", "to\\file")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].title").value("path\\to\\file"));
    }

    @Test
    void combinedFiltersSortAndPaginationWorkTogether() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-combined-filters");
        for (int i = 0; i < 5; i++) {
            seedTask("ada-combined-filters", "TODO-" + (char) ('A' + i), TaskStatus.TODO,
                    LocalDate.now(ZoneOffset.UTC).plusDays(i), null);
        }
        seedTask("ada-combined-filters", "IN_PROGRESS-task", TaskStatus.IN_PROGRESS,
                LocalDate.now(ZoneOffset.UTC).plusDays(1), null);

        mockMvc.perform(get("/api/v1/tasks")
                        .param("status", "TODO")
                        .param("sort", "title")
                        .param("direction", "ASC")
                        .param("page", "0")
                        .param("size", "2")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(5))
                .andExpect(jsonPath("$.data.content.length()").value(2))
                .andExpect(jsonPath("$.data.content[0].title").value("TODO-A"))
                .andExpect(jsonPath("$.data.content[1].title").value("TODO-B"));
    }

    @Test
    void putOnCompleteEndpointReturns405() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-405-put");
        String id = createTask(tokens, "{\"title\":\"m\"}");

        mockMvc.perform(put("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("METHOD_NOT_ALLOWED"));
    }

    @Test
    void unsupportedAcceptHeaderReturns406() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-406");

        mockMvc.perform(get("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .header(HttpHeaders.ACCEPT, "application/xml"))
                .andExpect(status().isNotAcceptable())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("NOT_ACCEPTABLE"));
    }

    @Test
    void overdueCannotBePersistedAsANormalStatus() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-overdue-status");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"bad\",\"status\":\"OVERDUE\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));

        assertThat(taskRepository.findByUserId(UUID.fromString(userIdOf("ada-overdue-status")))).isEmpty();
    }

    private String userIdOf(String username) {
        return userRepository.findByUsername(username).orElseThrow().getId().toString();
    }

    @Test
    void overdueIsDerivedNotPersisted() throws Exception {
        LocalDate past = LocalDate.now().minusDays(30);
        LocalDate future = LocalDate.now().plusDays(30);
        TokenResponse tokens = registerAndLogin("ada-overdue");

        String overdueId = createTask(tokens, "{\"title\":\"late\",\"dueDate\":\"" + past + "\"}");
        mockMvc.perform(get("/api/v1/tasks/" + overdueId).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overdue").value(true))
                .andExpect(jsonPath("$.data.status").value("TODO"));

        mockMvc.perform(patch("/api/v1/tasks/" + overdueId + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overdue").value(false));

        String inTimeId = createTask(tokens, "{\"title\":\"on time\",\"dueDate\":\"" + future + "\"}");
        mockMvc.perform(get("/api/v1/tasks/" + inTimeId).header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overdue").value(false));

        Task persisted = taskRepository.findById(UUID.fromString(overdueId)).orElseThrow();
        assertThat(persisted.getStatus()).isEqualTo(com.todoapp.entity.TaskStatus.COMPLETED);
    }

    // ------------------------------------------------------------ locking

    @Test
    void versionBumpsOnEveryWriteAndCreatedAtIsPreserved() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-version");
        String id = createTask(tokens, "{\"title\":\"v0\"}");

        MvcResult first = mockMvc.perform(put("/api/v1/tasks/" + id)
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"v1\",\"status\":\"IN_PROGRESS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.version").value(1))
                .andReturn();

        MvcResult second = mockMvc.perform(patch("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.version").value(2))
                .andReturn();

        JsonNode firstData = objectMapper.readTree(first.getResponse().getContentAsString()).path("data");
        JsonNode secondData = objectMapper.readTree(second.getResponse().getContentAsString()).path("data");
        assertThat(secondData.get("createdAt").asText())
                .isEqualTo(firstData.get("createdAt").asText());
        assertThat(secondData.get("updatedAt").asText())
                .isNotEqualTo(firstData.get("updatedAt").asText());
    }

    @Test
    void persistenceLayerStillEnforcesCompletedAtStatusCheck() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-db-check");
        String id = createTask(tokens, "{\"title\":\"consistent\"}");

        mockMvc.perform(patch("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"));

        Task task = taskRepository.findById(UUID.fromString(id)).orElseThrow();
        assertThat(task.getStatus()).hasToString("COMPLETED");
        assertThat(task.getCompletedAt()).isNotNull();
        assertThat(task.getCompletedAt()).isBeforeOrEqualTo(Instant.now());
    }

    // ------------------------------------------------------------ error contract

    @Test
    void wrongHttpMethodReturnsMethodNotAllowedEnvelope() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-method");
        String id = createTask(tokens, "{\"title\":\"m\"}");

        mockMvc.perform(get("/api/v1/tasks/" + id + "/complete")
                        .header("Authorization", bearer(tokens)))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("METHOD_NOT_ALLOWED"))
                .andExpect(jsonPath("$.path").value("/api/v1/tasks/" + id + "/complete"));
    }

    @Test
    void unsupportedContentTypeReturnsEnvelope() throws Exception {
        TokenResponse tokens = registerAndLogin("ada-media");

        mockMvc.perform(post("/api/v1/tasks")
                        .header("Authorization", bearer(tokens))
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("title=plain"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("UNSUPPORTED_MEDIA_TYPE"));
    }
}