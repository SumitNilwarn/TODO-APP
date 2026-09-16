package com.todoapp.exception;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.ApiError;
import com.todoapp.dto.FieldViolation;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.ConstraintViolationException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Translates exceptions into the standard {@link ApiError} envelope.
 * <p>
 * Client responses never include stack traces, credentials or internal details.
 * Unexpected exceptions are logged at ERROR with full detail for operators.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private final ObjectMapper objectMapper;

    public GlobalExceptionHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        log.warn("Validation failed for {} {}", request.getMethod(), request.getRequestURI());
        List<FieldViolation> details = ex.getBindingResult().getFieldErrors().stream()
            .map(error -> new FieldViolation(
                    error.getField(),
                    error.getDefaultMessage() == null ? "Invalid value" : error.getDefaultMessage()))
            .toList();
        ApiError body = ApiError.of(
                "VALIDATION_ERROR",
                "Request validation failed",
                details,
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<ApiError> handleConstraintViolation(ConstraintViolationException ex, HttpServletRequest request) {
        log.warn("Validation failed for {} {}", request.getMethod(), request.getRequestURI());
        List<FieldViolation> details = ex.getConstraintViolations().stream()
            .map(violation -> new FieldViolation(violation.getPropertyPath().toString(), violation.getMessage()))
            .toList();
        ApiError body = ApiError.of(
                "VALIDATION_ERROR",
                "Request validation failed",
                details,
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(FieldValidationException.class)
    ResponseEntity<ApiError> handleFieldValidation(FieldValidationException ex, HttpServletRequest request) {
        log.warn("Validation failed for {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                ex.getCode(),
                ex.getMessage(),
                ex.getViolations(),
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(OptimisticLockingFailureException.class)
    ResponseEntity<ApiError> handleOptimisticLock(OptimisticLockingFailureException ex,
                                                  HttpServletRequest request) {
        log.warn("Optimistic-lock conflict for {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                "OPTIMISTIC_LOCK_CONFLICT",
                "The resource has been concurrently modified; please retry",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ApiError> handleDataIntegrity(DataIntegrityViolationException ex,
                                                 HttpServletRequest request) {
        log.warn("Data-integrity conflict for {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                "CONFLICT",
                "The request conflicts with the current state of the resource",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> handleUnreadableBody(HttpMessageNotReadableException ex, HttpServletRequest request) {
        log.warn("Malformed request body for {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                "MALFORMED_REQUEST",
                "Request body is missing or malformed",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ApiError> handleTypeMismatch(MethodArgumentTypeMismatchException ex, HttpServletRequest request) {
        log.warn("Invalid request parameter '{}' for {} {}", ex.getName(), request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                "INVALID_PARAMETER",
                "Request parameter is invalid",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex, HttpServletRequest request) {
        log.warn("Illegal argument for {} {}: {}", request.getMethod(), request.getRequestURI(), ex.getMessage());
        ApiError body = ApiError.of(
                "ILLEGAL_ARGUMENT",
                "Request argument is invalid",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ApiError> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex,
                                                      HttpServletRequest request) {
        log.warn("HTTP method {} not allowed for {} {}", request.getMethod(),
                request.getRequestURI(), request.getProtocol());
        ApiError body = ApiError.of(
                "METHOD_NOT_ALLOWED",
                "HTTP method is not allowed for this resource",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(body);
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    ResponseEntity<ApiError> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException ex,
                                                        HttpServletRequest request) {
        log.warn("Unsupported content type for {} {}", request.getMethod(), request.getRequestURI());
        ApiError body = ApiError.of(
                "UNSUPPORTED_MEDIA_TYPE",
                "Request content type is not supported",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE).body(body);
    }

    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    void handleNotAcceptable(HttpMediaTypeNotAcceptableException ex,
                             HttpServletResponse response, HttpServletRequest request) throws IOException {
        log.warn("Not-acceptable content negotiation for {} {}", request.getMethod(), request.getRequestURI());
        // The client's Accept header cannot be satisfied by any of our handlers'
        // producible media types, so Spring would otherwise emit a 406 with an
        // empty body. Write the standard envelope directly (like the security
        // filters) so the error contract is preserved regardless of Accept.
        ApiError body = ApiError.of(
                "NOT_ACCEPTABLE",
                "Requested response content type is not supported",
                Instant.now(),
                request.getRequestURI());
        response.setStatus(HttpStatus.NOT_ACCEPTABLE.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), body);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> handleNotFound(NoResourceFoundException ex, HttpServletRequest request) {
        ApiError body = ApiError.of(
                "NOT_FOUND",
                "Resource not found",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> handleApiException(ApiException ex, HttpServletRequest request) {
        if (ex.getStatus().is5xxServerError()) {
            log.error("API {} {} for {} {}", ex.getCode(), ex.getStatus().value(),
                    request.getMethod(), request.getRequestURI(), ex);
        } else {
            log.warn("API {} {} for {} {}", ex.getCode(), ex.getStatus().value(),
                    request.getMethod(), request.getRequestURI());
        }
        ApiError body = ApiError.of(ex.getCode(), ex.getMessage(), Instant.now(), request.getRequestURI());
        return ResponseEntity.status(ex.getStatus()).body(body);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Unhandled exception for {} {}", request.getMethod(), request.getRequestURI(), ex);
        ApiError body = ApiError.of(
                "INTERNAL_ERROR",
                "An unexpected error occurred",
                Instant.now(),
                request.getRequestURI());
        return ResponseEntity.internalServerError().body(body);
    }
}