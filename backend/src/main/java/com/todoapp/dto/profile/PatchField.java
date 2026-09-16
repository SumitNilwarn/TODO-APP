package com.todoapp.dto.profile;

/**
 * Marks whether a JSON object field was present in a PATCH request body —
 * including an explicit {@code null} — versus omitted entirely.
 *
 * <p>PATCH semantics need three distinct states per field:
 * <ul>
 *   <li>omitted → leave the current value unchanged;</li>
 *   <li>explicit {@code null} → clear the field to {@code null};</li>
 *   <li>a string → validate, normalize and store it.</li>
 * </ul>
 * A plain {@code String} field cannot express this because Jackson maps both an
 * absent key and an explicit {@code null} to {@code null}. {@link PatchField}
 * is produced by {@link PatchFieldDeserializer} which keeps the distinction.
 */
public final class PatchField {

    private final boolean provided;
    private final String value;

    private PatchField(boolean provided, String value) {
        this.provided = provided;
        this.value = value;
    }

    public static PatchField omitted() {
        return new PatchField(false, null);
    }

    public static PatchField ofNull() {
        return new PatchField(true, null);
    }

    public static PatchField ofValue(String value) {
        return new PatchField(true, value);
    }

    public boolean isProvided() {
        return provided;
    }

    public String getValue() {
        return value;
    }
}