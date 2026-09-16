package com.todoapp.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.net.URI;
import java.net.URISyntaxException;

/**
 * Validates {@link ValidHttpUrl} values.
 *
 * <p>An absolute {@code http} or {@code https} URL with a non-empty host is
 * required. Relative paths ({@code /img/avatar.png}), other schemes ({@code
 * mailto}, {@code javascript}), IP-only hosts and malformed strings are all
 * rejected. The same static helper is reused by the service PATCH path so PUT
 * and PATCH share one canonical check.</p>
 */
public class HttpUrlValidator implements ConstraintValidator<ValidHttpUrl, String> {

    public static boolean isValidHttpUrl(String value) {
        try {
            URI uri = new URI(value);
            String scheme = uri.getScheme();
            return scheme != null
                    && (scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"))
                    && uri.getHost() != null;
        } catch (URISyntaxException ex) {
            return false;
        }
    }

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        return value == null || isValidHttpUrl(value);
    }
}