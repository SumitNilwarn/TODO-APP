package com.todoapp.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.todoapp.dto.HealthResponse;
import com.todoapp.dto.ReadinessResponse;
import com.todoapp.service.HealthService;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class HealthControllerTest {

    @Mock
    private HealthService healthService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper()
            .findAndRegisterModules()
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        mockMvc = MockMvcBuilders
            .standaloneSetup(new HealthController(healthService))
            .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
            .build();
    }

    @Test
    void healthReturnsSuccessEnvelope() throws Exception {
        when(healthService.getHealth())
            .thenReturn(new HealthResponse("UP", "todo-app-backend", Instant.parse("2026-01-01T00:00:00Z")));

        mockMvc.perform(get("/api/v1/health").accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.status").value("UP"))
            .andExpect(jsonPath("$.data.service").value("todo-app-backend"))
            .andExpect(jsonPath("$.data.timestamp").value("2026-01-01T00:00:00Z"));
    }

    @Test
    void readinessReturnsReadyWhenDatabaseIsUp() throws Exception {
        when(healthService.getReadiness())
            .thenReturn(new ReadinessResponse("READY", "UP", Instant.parse("2026-01-01T00:00:00Z")));

        mockMvc.perform(get("/api/v1/health/readiness").accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.status").value("READY"))
            .andExpect(jsonPath("$.data.database").value("UP"))
            .andExpect(jsonPath("$.data.timestamp").value("2026-01-01T00:00:00Z"));
    }
}