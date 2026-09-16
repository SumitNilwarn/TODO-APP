package com.todoapp.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

/**
 * Produces the standard 401 {@link ApiError} envelope for requests that reach
 * protected resources without valid authentication. At the filter stage the
 * global {@code @RestControllerAdvice} is not active, so this component writes
 * the JSON response directly.
 *
 * <p>{@link TokenAuthenticationException} codes ({@code TOKEN_EXPIRED},
 * {@code TOKEN_INVALID}) are propagated into the response; any other failure is
 * reported generically as {@code UNAUTHORIZED} to avoid leaking details.</p>
 */
@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private static final Logger log = LoggerFactory.getLogger(RestAuthenticationEntryPoint.class);

    private final ObjectMapper objectMapper;

    public RestAuthenticationEntryPoint(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        log.warn("Unauthenticated access to {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = buildBody(request, authException);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), body);
    }

    private static ApiError buildBody(HttpServletRequest request, AuthenticationException ex) {
        if (ex instanceof TokenAuthenticationException tokenException) {
            return ApiError.of(tokenException.getCode(), tokenException.getMessage(),
                    Instant.now(), request.getRequestURI());
        }
        return ApiError.of("UNAUTHORIZED", "Authentication is required",
                Instant.now(), request.getRequestURI());
    }
}