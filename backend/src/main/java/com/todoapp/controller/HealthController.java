package com.todoapp.controller;

import com.todoapp.dto.ApiResponse;
import com.todoapp.dto.HealthResponse;
import com.todoapp.dto.ReadinessResponse;
import com.todoapp.service.HealthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(ApiPaths.V1)
public class HealthController {

    private final HealthService healthService;

    public HealthController(HealthService healthService) {
        this.healthService = healthService;
    }

    @GetMapping("/health")
    public ResponseEntity<ApiResponse<HealthResponse>> health() {
        return ResponseEntity.ok(ApiResponse.success(healthService.getHealth()));
    }

    @GetMapping("/health/readiness")
    public ResponseEntity<ApiResponse<ReadinessResponse>> readiness() {
        return ResponseEntity.ok(ApiResponse.success(healthService.getReadiness()));
    }
}