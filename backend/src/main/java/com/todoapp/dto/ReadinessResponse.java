package com.todoapp.dto;

import java.time.Instant;

public record ReadinessResponse(String status, String database, Instant timestamp) {
}