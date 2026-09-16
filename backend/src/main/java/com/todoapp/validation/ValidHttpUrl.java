package com.todoapp.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Bean-validation constraint for http(s) URLs used as profile image references.
 *
 * <p>A {@code null} (or absent) value is valid: the image is optional. Anything
 * supplied must be an absolute {@code http(s)://} URL with a resolvable host —
 * relative paths, other schemes (mailto, javascript, ftp) and malformed strings
 * are rejected. The logic is shared with the PATCH path via
 * {@link HttpUrlValidator#isValidHttpUrl(String)} so PUT and PATCH behave
 * identically.</p>
 */
@Documented
@Constraint(validatedBy = HttpUrlValidator.class)
@Target({ElementType.METHOD, ElementType.FIELD, ElementType.PARAMETER,
        ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidHttpUrl {

    String message() default "must be a valid http(s) URL";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}