package com.todoapp.service;

import com.todoapp.dto.HealthResponse;
import com.todoapp.dto.ReadinessResponse;
import com.todoapp.exception.ServiceUnavailableException;
import java.time.Instant;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class HealthService {

    private static final String SERVICE_NAME = "todo-app-backend";

    private final JdbcTemplate jdbcTemplate;

    public HealthService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public HealthResponse getHealth() {
        return new HealthResponse("UP", SERVICE_NAME, Instant.now());
    }

    public ReadinessResponse getReadiness() {
        Instant now = Instant.now();
        try {
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            return new ReadinessResponse("READY", "UP", now);
        } catch (DataAccessException ex) {
            throw new ServiceUnavailableException("Database is not reachable", ex);
        }
    }
}