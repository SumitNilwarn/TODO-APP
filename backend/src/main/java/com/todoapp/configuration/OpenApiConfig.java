package com.todoapp.configuration;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI / Swagger documentation conventions.
 * <p>
 * API versioning is path based ({@code /api/v1}). Every endpoint returns the
 * standard envelopes defined in {@code com.todoapp.dto}:
 * {@code ApiResponse} for success and {@code ApiError} for errors.
 * <p>
 * The Bearer JWT scheme applies to all protected endpoints. The public auth
 * endpoints ({@code /api/v1/auth/**}) and health checks ({@code /api/v1/health/**})
 * do not require authentication.
 */
@Configuration
public class OpenApiConfig {

    private static final String BEARER = "Bearer JWT";

    @Bean
    OpenAPI todoAppOpenApi() {
        return new OpenAPI()
            .info(new Info()
                .title("Todo App API")
                .description("REST API for the Todo App. "
                    + "All endpoints are versioned under /api/v1. "
                    + "Successful responses use the ApiResponse envelope; errors use the "
                    + "ApiError envelope (see docs/api-overview.md). "
                    + "Authentication, the user profile endpoints, the task endpoints "
                    + "(CRUD plus pagination, filtering, sorting and search) and the "
                    + "dashboard statistics endpoint are all implemented.")
                .version("v1")
                .contact(new Contact().name("Todo App Team")))
            .addSecurityItem(new SecurityRequirement().addList(BEARER))
            .components(new Components()
                .addSecuritySchemes(BEARER, new SecurityScheme()
                    .name("Authorization")
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")));
    }
}