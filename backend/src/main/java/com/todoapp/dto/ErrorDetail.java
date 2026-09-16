package com.todoapp.dto;

import java.util.List;

public record ErrorDetail(String code, String message, List<FieldViolation> details) {
}