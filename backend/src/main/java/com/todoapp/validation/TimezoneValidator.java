package com.todoapp.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.time.ZoneId;
import java.util.Set;

/**
 * Validates {@link ValidTimezone} values against the IANA timezone registry.
 *
 * <p>The tz database shipped with the JDK ({@link ZoneId#getAvailableZoneIds()})
 * is used, so no external data source or network call is involved. A small set
 * of widely used aliases that users commonly type ({@code UTC}, {@code GMT},
 * {@code UT}, {@code GMT0}) is accepted explicitly; three-letter abbreviations
 * such as {@code EST} or {@code PST} are rejected because they are legacy
 * {@code TimeZone} identifiers, not IANA zones. A blank/unknown value fails;
 * {@code null} passes (the field is optional).</p>
 */
public class TimezoneValidator implements ConstraintValidator<ValidTimezone, String> {

    private static final Set<String> AVAILABLE_ZONE_IDS = ZoneId.getAvailableZoneIds();
    private static final Set<String> ACCEPTED_ALIASES =
            Set.of("UTC", "GMT", "UT", "GMT0", "UT0", "Etc/UTC");

    public static boolean isValidTimezone(String value) {
        return value == null || AVAILABLE_ZONE_IDS.contains(value) || ACCEPTED_ALIASES.contains(value);
    }

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        return isValidTimezone(value);
    }
}