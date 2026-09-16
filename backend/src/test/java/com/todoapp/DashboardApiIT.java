package com.todoapp;

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

import static org.hamcrest.Matchers.greaterThan;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end dashboard API tests over the real security filter chain and a real
 * PostgreSQL 16 container (Flyway V1-V4 schema + Hibernate validate). Each test
 * is transactional: HTTP requests join the test transaction and rows never leak
 * between tests.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DashboardApiIT {

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

    private TokenResponse registerAndLogin(String username) throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(username, username + "@example.com", PASSWORD))))
                .andExpect(status().isCreated())
                .andReturn();
        MvcResult login = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(username, PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.treeToValue(
                objectMapper.readTree(login.getResponse().getContentAsString()).path("data"),
                TokenResponse.class);
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

    private void seedTask(String username, String title, TaskStatus status, LocalDate dueDate) {
        User owner = userRepository.findByUsername(username).orElseThrow();
        Task task = new Task(owner, title);
        task.setStatus(status);
        task.setDueDate(dueDate);
        if (status == TaskStatus.COMPLETED) {
            task.setCompletedAt(Instant.now().plusSeconds(1));
        }
        taskRepository.saveAndFlush(task);
    }

    private static String bearer(TokenResponse tokens) {
        return "Bearer " + tokens.accessToken();
    }

    private static void setStatus(User user, AccountStatus status) {
        user.setAccountStatus(status);
    }

    @Test
    void unauthenticatedDashboardRequestIsRejected() throws Exception {
        mockMvc.perform(get("/api/v1/dashboard"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void zeroTaskDashboardReturnsZeroCounts() throws Exception {
        TokenResponse tokens = registerAndLogin("dash-empty");

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.totalTasks").value(0))
                .andExpect(jsonPath("$.data.todoTasks").value(0))
                .andExpect(jsonPath("$.data.inProgressTasks").value(0))
                .andExpect(jsonPath("$.data.completedTasks").value(0))
                .andExpect(jsonPath("$.data.cancelledTasks").value(0))
                .andExpect(jsonPath("$.data.overdueTasks").value(0))
                .andExpect(jsonPath("$.data.userId").doesNotExist());
    }

    @Test
    void dashboardReturnsCorrectMixedCounts() throws Exception {
        TokenResponse tokens = registerAndLogin("dash-mixed");
        LocalDate past = LocalDate.now(ZoneOffset.UTC).minusDays(1);
        LocalDate future = LocalDate.now(ZoneOffset.UTC).plusDays(3);
        for (int i = 0; i < 5; i++) {
            seedTask("dash-mixed", "todo-" + i, TaskStatus.TODO, i < 2 ? past : null);
        }
        seedTask("dash-mixed", "ip-1", TaskStatus.IN_PROGRESS, past);
        seedTask("dash-mixed", "ip-2", TaskStatus.IN_PROGRESS, future);
        seedTask("dash-mixed", "ip-3", TaskStatus.IN_PROGRESS, null);
        for (int i = 0; i < 3; i++) {
            seedTask("dash-mixed", "done-" + i, TaskStatus.COMPLETED, i < 2 ? past : future);
        }
        seedTask("dash-mixed", "cancel-1", TaskStatus.CANCELLED, past);
        seedTask("dash-mixed", "cancel-2", TaskStatus.CANCELLED, null);

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalTasks").value(13))
                .andExpect(jsonPath("$.data.todoTasks").value(5))
                .andExpect(jsonPath("$.data.inProgressTasks").value(3))
                .andExpect(jsonPath("$.data.completedTasks").value(3))
                .andExpect(jsonPath("$.data.cancelledTasks").value(2))
                .andExpect(jsonPath("$.data.overdueTasks").value(3));
    }

    @Test
    void completedAndCancelledPastDueTasksAreNeverOverdue() throws Exception {
        TokenResponse tokens = registerAndLogin("dash-notoverdue");
        LocalDate past = LocalDate.now(ZoneOffset.UTC).minusDays(30);
        seedTask("dash-notoverdue", "done-old", TaskStatus.COMPLETED, past);
        seedTask("dash-notoverdue", "cancel-old", TaskStatus.CANCELLED, past);
        seedTask("dash-notoverdue", "active-old", TaskStatus.IN_PROGRESS, past);

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalTasks").value(3))
                .andExpect(jsonPath("$.data.overdueTasks").value(1));
    }

    @Test
    void dashboardCountsAreIsolatedPerUser() throws Exception {
        TokenResponse a = registerAndLogin("dash-user-a");
        TokenResponse b = registerAndLogin("dash-user-b");
        LocalDate past = LocalDate.now(ZoneOffset.UTC).minusDays(2);
        seedTask("dash-user-a", "a1", TaskStatus.TODO, past);
        seedTask("dash-user-a", "a2", TaskStatus.COMPLETED, past);
        seedTask("dash-user-a", "a3", TaskStatus.CANCELLED, null);
        for (int i = 0; i < 8; i++) {
            seedTask("dash-user-b", "b" + i, TaskStatus.IN_PROGRESS, null);
        }

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(a)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalTasks").value(3))
                .andExpect(jsonPath("$.data.todoTasks").value(1))
                .andExpect(jsonPath("$.data.inProgressTasks").value(0))
                .andExpect(jsonPath("$.data.completedTasks").value(1))
                .andExpect(jsonPath("$.data.cancelledTasks").value(1))
                .andExpect(jsonPath("$.data.overdueTasks").value(1));

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(b)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalTasks").value(8))
                .andExpect(jsonPath("$.data.inProgressTasks").value(8))
                .andExpect(jsonPath("$.data.todoTasks").value(0))
                .andExpect(jsonPath("$.data.overdueTasks").value(0));
    }

    @Test
    void singleUserOnlyDashboardCountsAreExposed() throws Exception {
        TokenResponse tokens = registerAndLogin("dash-positive");
        seedTask("dash-positive", "x", TaskStatus.TODO, null);

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalTasks", greaterThan(0)));
    }

    @Test
    void disabledAccountCannotAccessDashboard() throws Exception {
        registerAndLogin("dash-disabled");
        TokenResponse tokens = login("dash-disabled");
        setStatus(userRepository.findByUsername("dash-disabled").orElseThrow(), AccountStatus.DISABLED);
        userRepository.flush();

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void lockedAccountCannotAccessDashboard() throws Exception {
        registerAndLogin("dash-locked");
        TokenResponse tokens = login("dash-locked");
        setStatus(userRepository.findByUsername("dash-locked").orElseThrow(), AccountStatus.LOCKED);
        userRepository.flush();

        mockMvc.perform(get("/api/v1/dashboard").header("Authorization", bearer(tokens)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }
}