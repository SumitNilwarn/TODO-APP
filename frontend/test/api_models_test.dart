import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_envelope.dart';
import 'package:todo_app/data/api/api_error.dart';
import 'package:todo_app/data/api/api_response.dart';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('ApiErrorDetail', () {
    test('parses the backend field detail shape', () {
      final detail = ApiErrorDetail.fromJson(
        _decode('''{"field":"dueDate","message":"must not be null"}'''),
      );
      expect(detail.field, 'dueDate');
      expect(detail.message, 'must not be null');
    });

    test('defaults missing fields', () {
      final detail = ApiErrorDetail.fromJson(const {});
      expect(detail.field, isNull);
      expect(detail.message, isNull);
    });
  });

  group('ApiError', () {
    test('parses a full error block with details', () {
      final error = ApiError.fromJson(
        _decode('''
      {
        "code": "VALIDATION_ERROR",
        "message": "Request validation failed",
        "details": [
          {"field": "dueDate", "message": "must not be null"}
        ]
      }
      '''),
      );
      expect(error.code, 'VALIDATION_ERROR');
      expect(error.message, 'Request validation failed');
      expect(error.details, hasLength(1));
      expect(error.details.first.field, 'dueDate');
    });

    test('defaults missing optional fields and unknown codes', () {
      final error = ApiError.fromJson(const {});
      expect(error.code, 'UNKNOWN_ERROR');
      expect(error.message, isNull);
      expect(error.details, isEmpty);
      expect(error.timestamp, isNull);
      expect(error.path, isNull);
    });
  });

  group('ApiEnvelope', () {
    test('recognizes a success envelope', () {
      final envelope = ApiEnvelope.fromJson(
        _decode('''
      {
        "success": true,
        "data": {"id": "abc"},
        "message": null,
        "timestamp": "2026-01-01T00:00:00Z",
        "path": "/api/v1/tasks"
      }
      '''),
      );
      expect(envelope.success, isTrue);
      expect(envelope.hasError, isFalse);
      expect((envelope.data as Map)['id'], 'abc');
      expect(envelope.timestamp, isNotNull);
      expect(envelope.path, '/api/v1/tasks');
    });

    test('recognizes an error envelope', () {
      final envelope = ApiEnvelope.fromJson(
        _decode('''
      {
        "success": false,
        "error": {"code": "TASK_NOT_FOUND", "message": "Task not found"},
        "timestamp": "2026-01-01T00:00:00Z",
        "path": "/api/v1/tasks/123"
      }
      '''),
      );
      expect(envelope.success, isFalse);
      expect(envelope.hasError, isTrue);
      expect(envelope.error?.code, 'TASK_NOT_FOUND');
      expect(envelope.data, isNull);
    });
  });

  group('ApiResponse', () {
    test('decodes typed data through the dataParser', () {
      final envelope = ApiEnvelope.fromJson(
        _decode('{"success": true, "data": {"value": 42}}'),
      );
      final response = ApiResponse<Map<String, dynamic>>.fromEnvelope(
        envelope,
        dataParser: (data) => (data as Map).cast<String, dynamic>(),
      );
      expect(response.success, isTrue);
      expect(response.error, isNull);
      expect(response.data?['value'], 42);
    });

    test('carries the parsed error on failure', () {
      final envelope = ApiEnvelope.fromJson(
        _decode('{"success": false, "error": {"code": "NETWORK_INVALID"}}'),
      );
      final response = ApiResponse<Object?>.fromEnvelope(
        envelope,
        dataParser: (data) => data,
      );
      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.error?.code, 'NETWORK_INVALID');
    });

    test('tolerates a missing data payload', () {
      final envelope = ApiEnvelope.fromJson(
        _decode('{"success": true, "data": null}'),
      );
      final response = ApiResponse<int>.fromEnvelope(
        envelope,
        dataParser: (data) => data as int,
      );
      expect(response.success, isTrue);
      expect(response.data, isNull);
    });

    test('fromJson convenience parses a success envelope', () {
      final response = ApiResponse<Map<String, dynamic>>.fromJson(
        _decode('{"success": true, "data": {"ok": true}}'),
        dataParser: (data) => (data as Map).cast<String, dynamic>(),
      );
      expect(response.success, isTrue);
      expect(response.data?['ok'], isTrue);
    });
  });
}
