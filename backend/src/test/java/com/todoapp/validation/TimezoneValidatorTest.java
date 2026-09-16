package com.todoapp.validation;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class TimezoneValidatorTest {

    @Test
    void acceptsNullBecauseTimezoneIsOptional() {
        assertThat(TimezoneValidator.isValidTimezone(null)).isTrue();
    }

    @Test
    void acceptsRealIanaZonesAndUtcGmtAliases() {
        for (String zone : new String[]{
                "Asia/Kolkata", "Europe/London", "America/New_York",
                "Asia/Tokyo", "Australia/Sydney", "Etc/UTC", "UTC", "GMT",
                "US/Eastern", "Asia/Calcutta"}) {
            assertThat(TimezoneValidator.isValidTimezone(zone))
                    .as("expected %s to be valid", zone)
                    .isTrue();
        }
    }

    @Test
    void rejectsUnknownAndMalformedZones() {
        for (String zone : new String[]{
                "Banana/Island", "Asia/Kolkata/", "europe/london",
                "GMT+05:30", "+05:30", "EST", "PST", "EST", ""}) {
            assertThat(TimezoneValidator.isValidTimezone(zone))
                    .as("expected %s to be invalid", zone)
                    .isFalse();
        }
    }
}