package com.todoapp.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Bean-validation twin of {@code @NotBlank} that treats {@code null} as valid.
 *
 * <p>The profile model allows a field to be cleared with {@code null} ("remove
 * the value") while rejecting blank strings ("no accidental whitespace-only
 * values"). Hibernate Validator's built-in {@code @NotBlank} rejects {@code null}
 * in this stack, so the allow-null semantics are spelled out here explicitly.
 */
@Documented
@Constraint(validatedBy = NotBlankOrNullValidator.class)
@Target({ElementType.METHOD, ElementType.FIELD, ElementType.RECORD_COMPONENT,
        ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface NotBlankOrNull {

    String message() default "must not be blank";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}