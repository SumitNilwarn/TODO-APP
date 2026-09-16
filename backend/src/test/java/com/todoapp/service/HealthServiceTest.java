package com.todoapp.service;

import com.todoapp.dto.HealthResponse;
import com.todoapp.dto.ReadinessResponse;
import com.todoapp.exception.ServiceUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HealthServiceTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    private HealthService healthService;

    @BeforeEach
    void setUp() {
        healthService = new HealthService(jdbcTemplate);
    }

    @Test
    void returnsUpStatus() {
        HealthResponse response = healthService.getHealth();
        assertThat(response.status()).isEqualTo("UP");
        assertThat(response.service()).isEqualTo("todo-app-backend");
        assertThat(response.timestamp()).isNotNull();
    }

    @Test
    void reportsReadyWhenDatabaseIsReachable() {
        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class)).thenReturn(1);

        ReadinessResponse response = healthService.getReadiness();

        assertThat(response.status()).isEqualTo("READY");
        assertThat(response.database()).isEqualTo("UP");
        assertThat(response.timestamp()).isNotNull();
    }

    @Test
    void throwsServiceUnavailableWhenDatabaseIsDown() {
        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class))
            .thenThrow(new CannotGetJdbcConnectionException("connection refused", new IllegalStateException("docker down")));

        assertThatThrownBy(() -> healthService.getReadiness())
            .isInstanceOf(ServiceUnavailableException.class)
            .hasMessage("Database is not reachable");
    }
}