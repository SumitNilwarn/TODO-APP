package com.todoapp.exception;

import com.todoapp.dto.FieldViolation;
import java.util.List;
import org.springframework.http.HttpStatus;

/**
 * Programmatic validation failure carrying structured field violations (HTTP
 * 400 {@code VALIDATION_ERROR}).
 *
 * <p>Used when validation runs in the service layer rather than through
 * bean-validation annotations — for example the PATCH path, where a
 * {@link com.todoapp.dto.profile.PatchField} must be distinguished per-field
 * before its value can be checked. The {@code GlobalExceptionHandler} renders
 * this with the same envelope and field details as annotation-based
 * validation.</p>
 */
public class FieldValidationException extends ApiException {

    private final List<FieldViolation> violations;

    public FieldValidationException(List<FieldViolation> violations) {
        super(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Request validation failed");
        this.violations = List.copyOf(violations);
    }

    public List<FieldViolation> getViolations() {
        return violations;
    }
}