package com.todoapp.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Bean-validation constraint for IANA timezone identifiers.
 *
 * <p>A {@code null} (or absent) value is valid: the timezone is optional and the
 * application falls back to UTC until the user sets one. Anything supplied must
 * be a real IANA timezone ({@code Asia/Kolkata}) or the {@code UTC}/{@code GMT}
 * aliases — unknown or typo'd identifiers are rejected, never silently mapped
 * to Greenwich.</p>
 */
@Documented
@Constraint(validatedBy = TimezoneValidator.class)
@Target({ElementType.METHOD, ElementType.FIELD, ElementType.PARAMETER,
        ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidTimezone {

    String message() default "must be a valid IANA timezone identifier (e.g. Asia/Kolkata) or UTC/GMT";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}