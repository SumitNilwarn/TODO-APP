package com.todoapp.dto.task;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.JsonMappingException;
import java.io.IOException;

/**
 * Deserializes a single task PATCH field: a string becomes a provided raw
 * value, an explicit JSON {@code null} becomes a provided-null (meaning
 * "clear"), and a missing key leaves the {@link TaskPatchValue} omitted.
 * Anything else (numbers, objects, arrays) is rejected by Jackson as a
 * malformed body.
 */
public final class TaskPatchValueDeserializer extends JsonDeserializer<TaskPatchValue> {

    @Override
    public TaskPatchValue deserialize(JsonParser parser, DeserializationContext context)
            throws IOException {
        JsonToken token = parser.currentToken();
        if (token == JsonToken.VALUE_NULL) {
            return TaskPatchValue.ofNull();
        }
        if (token == JsonToken.VALUE_STRING) {
            return TaskPatchValue.of(parser.getText());
        }
        throw new JsonMappingException(parser,
                "Expected a string value or null for PATCH field");
    }
}