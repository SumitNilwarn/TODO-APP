package com.todoapp.dto.profile;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.JsonMappingException;
import java.io.IOException;

/**
 * Deserializes a single PATCH field: a string becomes a provided value, an
 * explicit JSON {@code null} becomes a provided-null (meaning "clear"), and a
 * missing key leaves the {@link PatchField} as omitted. Anything else (numbers,
 * objects, arrays) is rejected by Jackson as a malformed body.
 */
public final class PatchFieldDeserializer extends JsonDeserializer<PatchField> {

    @Override
    public PatchField deserialize(JsonParser parser, DeserializationContext context)
            throws IOException {
        JsonToken token = parser.currentToken();
        if (token == JsonToken.VALUE_NULL) {
            return PatchField.ofNull();
        }
        if (token == JsonToken.VALUE_STRING) {
            return PatchField.ofValue(parser.getText());
        }
        throw new JsonMappingException(parser,
                "Expected a string value or null for PATCH field");
    }
}