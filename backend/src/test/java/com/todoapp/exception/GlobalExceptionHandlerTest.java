package com.todoapp.exception;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.ApiError;
import com.todoapp.dto.FieldViolation;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler =
            new GlobalExceptionHandler(new ObjectMapper().findAndRegisterModules());

    private MockHttpServletRequest request(String method, String uri) {
        return new MockHttpServletRequest(method, uri);
    }

    @Test
    void validationFailuresReturnEnvelopeWithFieldDetails() {
        BeanPropertyBindingResult binding = new BeanPropertyBindingResult(new Object(), "command");
        binding.addError(new FieldError("command", "title", "must not be blank"));
        binding.addError(new FieldError("command", "dueDate", "must not be null"));
        MethodArgumentNotValidException ex = new MethodArgumentNotValidException(null, binding);

        ResponseEntity<ApiError> response = handler.handleValidation(ex, request("POST", "/api/v1/health"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("VALIDATION_ERROR");
        assertThat(response.getBody().error().details()).containsExactly(
                new FieldViolation("title", "must not be blank"),
                new FieldViolation("dueDate", "must not be null"));
        assertThat(response.getBody().path()).isEqualTo("/api/v1/health");
        assertThat(response.getBody().timestamp()).isNotNull();
    }

    @Test
    void malformedBodyReturnsMalformedRequestError() {
        HttpMessageNotReadableException ex = new HttpMessageNotReadableException("body missing");

        ResponseEntity<ApiError> response = handler.handleUnreadableBody(ex, request("POST", "/api/v1/health"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().error().code()).isEqualTo("MALFORMED_REQUEST");
    }

    @Test
    void resourceNotFoundReturnsNotFoundError() {
        NoResourceFoundException ex = new NoResourceFoundException(org.springframework.http.HttpMethod.GET, "/api/v1/missing");

        ResponseEntity<ApiError> response = handler.handleNotFound(ex, request("GET", "/api/v1/missing"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody().error().code()).isEqualTo("NOT_FOUND");
    }

    @Test
    void typeMismatchReturnsInvalidParameterError() {
        MethodArgumentTypeMismatchException ex =
                new MethodArgumentTypeMismatchException("abc", Integer.class, "page", null, null);

        ResponseEntity<ApiError> response = handler.handleTypeMismatch(ex, request("GET", "/api/v1/health"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().error().code()).isEqualTo("INVALID_PARAMETER");
    }

    @Test
    void illegalArgumentReturnsBadRequestError() {
        ResponseEntity<ApiError> response =
                handler.handleIllegalArgument(new IllegalArgumentException("oops"), request("POST", "/api/v1/health"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().error().code()).isEqualTo("ILLEGAL_ARGUMENT");
    }

    @Test
    void apiExceptionUsesItsStatusAndCode() {
        ResponseEntity<ApiError> response = handler.handleApiException(
                new ResourceNotFoundException("Task not found"), request("GET", "/api/v1/tasks/42"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("NOT_FOUND");
        assertThat(response.getBody().error().message()).isEqualTo("Task not found");
    }

    @Test
    void fieldValidationExceptionReturnsEnvelopeWithFieldDetails() {
        FieldValidationException ex = new FieldValidationException(List.of(
                new FieldViolation("timezone", "must be a valid IANA timezone identifier")));

        ResponseEntity<ApiError> response = handler.handleFieldValidation(
                ex, request("PATCH", "/api/v1/profile"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("VALIDATION_ERROR");
        assertThat(response.getBody().error().details()).containsExactly(
                new FieldViolation("timezone", "must be a valid IANA timezone identifier"));
    }

    @Test
    void optimisticLockConflictReturnsConflictError() {
        ObjectOptimisticLockingFailureException ex =
                new ObjectOptimisticLockingFailureException(Object.class, 1L);

        ResponseEntity<ApiError> response = handler.handleOptimisticLock(
                ex, request("PUT", "/api/v1/profile"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().error().code()).isEqualTo("OPTIMISTIC_LOCK_CONFLICT");
    }

    @Test
    void dataIntegrityViolationReturnsConflictError() {
        ResponseEntity<ApiError> response = handler.handleDataIntegrity(
                new DataIntegrityViolationException("duplicate"), request("PUT", "/api/v1/profile"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().error().code()).isEqualTo("CONFLICT");
    }

    @Test
    void methodNotSupportedReturnsMethodNotAllowedEnvelope() {
        HttpRequestMethodNotSupportedException ex =
                new HttpRequestMethodNotSupportedException("GET", List.of("PATCH"));

        ResponseEntity<ApiError> response =
                handler.handleMethodNotSupported(ex, request("GET", "/api/v1/tasks/42/complete"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.METHOD_NOT_ALLOWED);
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("METHOD_NOT_ALLOWED");
        assertThat(response.getBody().error().details()).isEqualTo(List.of());
    }

    @Test
    void unsupportedMediaTypeReturnsEnvelope() {
        HttpMediaTypeNotSupportedException ex =
                new HttpMediaTypeNotSupportedException("text/plain not supported");

        ResponseEntity<ApiError> response =
                handler.handleUnsupportedMediaType(ex, request("POST", "/api/v1/tasks"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNSUPPORTED_MEDIA_TYPE);
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("UNSUPPORTED_MEDIA_TYPE");
        assertThat(response.getBody().error().details()).isEqualTo(List.of());
    }

    @Test
    void notAcceptableReturnsEnvelope() throws Exception {
        HttpMediaTypeNotAcceptableException ex =
                new HttpMediaTypeNotAcceptableException(List.of(MediaType.APPLICATION_XML));
        MockHttpServletResponse response = new MockHttpServletResponse();

        handler.handleNotAcceptable(ex, response, request("GET", "/api/v1/health"));

        assertThat(response.getStatus()).isEqualTo(HttpStatus.NOT_ACCEPTABLE.value());
        assertThat(response.getContentType()).startsWith("application/json");
        ApiError body = new ObjectMapper().findAndRegisterModules()
                .readValue(response.getContentAsString(), ApiError.class);
        assertThat(body.success()).isFalse();
        assertThat(body.error().code()).isEqualTo("NOT_ACCEPTABLE");
        assertThat(body.error().details()).isEqualTo(List.of());
    }

    @Test
    void unexpectedExceptionReturnsSafeResponseWithoutInternalDetails() {
        ResponseEntity<ApiError> response = handler.handleUnexpected(
                new IllegalStateException("secret-db-credentials: password=supersecret"),
                request("GET", "/api/v1/health"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody().success()).isFalse();
        assertThat(response.getBody().error().code()).isEqualTo("INTERNAL_ERROR");
        assertThat(response.getBody().error().message()).isEqualTo("An unexpected error occurred");
        assertThat(response.getBody().error().message()).doesNotContain("secret-db-credentials");
        assertThat(response.getBody().error().details()).isEqualTo(List.of());
    }
}