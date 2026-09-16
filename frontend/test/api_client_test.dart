import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_app/data/api/api_client.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/data/api/api_interceptor.dart';
import 'package:todo_app/data/api/api_paths.dart';

const _base = 'http://test.local';

ApiClient _client(MockClient mock, {List<ApiInterceptor>? interceptors}) {
  return ApiClient(
    baseUrl: _base,
    httpClient: mock,
    interceptors: interceptors,
  );
}

Map<String, dynamic> _parseData(dynamic data) =>
    (data as Map).cast<String, dynamic>();

http.Response _json(Object body, int status) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('ApiClient — transport', () {
    test('normalizes the base URL', () {
      final api = ApiClient(
        baseUrl: '  http://test.local//  ',
        httpClient: MockClient((_) async => _json({'success': true}, 200)),
      );
      expect(api.baseUrl, 'http://test.local');
    });

    test('GET resolves path and decodes typed data', () async {
      final api = _client(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), '$_base/api/v1/things');
          expect(request.headers['accept'], 'application/json');
          return _json({
            'success': true,
            'data': {'value': 7},
          }, 200);
        }),
      );

      final response = await api.get<Map<String, dynamic>>(
        '${ApiPaths.v1}/things',
        dataParser: _parseData,
      );
      expect(response.success, isTrue);
      expect(response.data?['value'], 7);
    });

    test('encodes query parameters', () async {
      final api = _client(
        MockClient((request) async {
          expect(request.url.queryParameters['overdue'], 'true');
          expect(request.url.queryParameters['page'], '2');
          return _json({'success': true, 'data': null}, 200);
        }),
      );

      await api.get<Object?>(
        '${ApiPaths.v1}/tasks',
        queryParameters: {'overdue': 'true', 'page': '2'},
        dataParser: (data) => data,
      );
    });

    test('POST serializes the body as JSON', () async {
      final api = _client(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'title': 'x',
            'nested': {'a': 1},
          });
          return _json({'success': true, 'data': null}, 201);
        }),
      );

      final response = await api.post<Object?>(
        '${ApiPaths.v1}/things',
        body: {
          'title': 'x',
          'nested': {'a': 1},
        },
        dataParser: (data) => data,
      );
      expect(response.success, isTrue);
    });

    test('PATCH and DELETE are routed with the expected methods', () async {
      final seen = <String>[];
      final api = _client(
        MockClient((request) async {
          seen.add(request.method);
          return _json({'success': true, 'data': null}, 200);
        }),
      );

      await api.patch<Object?>(
        '${ApiPaths.v1}/things/1',
        body: {'title': 'x'},
        dataParser: (data) => data,
      );
      await api.delete<Object?>(
        '${ApiPaths.v1}/things/1',
        dataParser: (data) => data,
      );
      expect(seen, ['PATCH', 'DELETE']);
    });

    test('a 2xx empty body is a success with no data', () async {
      final api = _client(MockClient((_) async => http.Response('', 204)));
      final response = await api.get<Object?>(
        '/empty',
        dataParser: (data) => data,
      );
      expect(response.success, isTrue);
      expect(response.data, isNull);
    });
  });

  group('ApiClient — errors', () {
    test(
      'non-2xx with an error envelope throws a parsed ApiException',
      () async {
        final api = _client(
          MockClient((_) async {
            return _json({
              'success': false,
              'error': {
                'code': 'TASK_NOT_FOUND',
                'message': 'Task not found',
                'details': [
                  {'field': 'id', 'message': 'no such task'},
                ],
              },
              'path': '/api/v1/tasks/abc',
            }, 404);
          }),
        );

        await expectLater(
          api.get<Object?>('${ApiPaths.v1}/tasks/abc', dataParser: (d) => d),
          throwsA(
            isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiExceptionKind.server)
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.code, 'code', 'TASK_NOT_FOUND')
                .having((e) => e.details.length, 'details', 1),
          ),
        );
      },
    );

    test('non-2xx without JSON surfaces the HTTP status', () async {
      final api = _client(
        MockClient((_) async => http.Response('backend is down', 503)),
      );

      await expectLater(
        api.get<Object?>('/health', dataParser: (d) => d),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.invalid)
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('transport failures surface a network ApiException', () async {
      final api = _client(
        MockClient((_) async => throw http.ClientException('refused')),
      );

      await expectLater(
        api.get<Object?>('/anything', dataParser: (d) => d),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'isNetworkError',
            isTrue,
          ),
        ),
      );
    });

    test(
      'a backend that stalls mid-body still surfaces a timeout ApiException',
      () async {
        // The challenge: `_http.send(...)` completes once headers arrive, so a
        // server that never finishes streaming its body must also be bounded by
        // `timeout`. `_StallingBodyClient` returns headers immediately and a
        // body stream that never completes (F1 regression).
        final bodyController = StreamController<List<int>>();
        addTearDown(bodyController.close);
        final api = ApiClient(
          baseUrl: _base,
          httpClient: _StallingBodyClient(bodyController),
          timeout: const Duration(milliseconds: 30),
        );

        await expectLater(
          api.get<Object?>('/stalled-body', dataParser: (d) => d),
          throwsA(
            isA<ApiException>().having((e) => e.isTimeout, 'isTimeout', isTrue),
          ),
        );
      },
    );

    test(
      'forwards the outer-envelope path and timestamp into the exception',
      () async {
        // The real backend emits `path`/`timestamp` at the envelope level, not
        // inside the nested `error` block — the client must surface them.
        final api = _client(
          MockClient((_) async {
            return _json({
              'success': false,
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Request validation failed',
                'details': [
                  {'field': 'search', 'message': 'must be at most 200'},
                ],
              },
              'timestamp': '2026-09-15T08:30:00Z',
              'path': '/api/v1/tasks',
            }, 400);
          }),
        );

        await expectLater(
          api.get<Object?>('${ApiPaths.v1}/tasks', dataParser: (d) => d),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'VALIDATION_ERROR')
                .having((e) => e.path, 'path', '/api/v1/tasks')
                .having(
                  (e) => e.timestamp,
                  'timestamp',
                  DateTime.utc(2026, 9, 15, 8, 30),
                ),
          ),
        );
      },
    );

    test('timeouts surface a timeout ApiException', () async {
      final api = ApiClient(
        baseUrl: _base,
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _json({'success': true, 'data': null}, 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        api.get<Object?>('/slow', dataParser: (d) => d),
        throwsA(
          isA<ApiException>().having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
    });
  });

  group('ApiClient — correlation ids', () {
    test('sends a generated X-Correlation-Id on every request', () async {
      final seen = <String?>[];
      final api = _client(
        MockClient((request) async {
          seen.add(request.headers['x-correlation-id']);
          return _json({
            'success': true,
            'data': {'ok': 1},
          }, 200);
        }),
      );

      await api.get<Map<String, dynamic>>(
        '${ApiPaths.v1}/things',
        dataParser: _parseData,
      );
      await api.get<Map<String, dynamic>>(
        '${ApiPaths.v1}/things',
        dataParser: _parseData,
      );

      expect(seen, hasLength(2));
      expect(seen.first, isNotNull);
      expect(seen.first, isNotEmpty);
      expect(
        seen.first,
        isNot(seen.last),
        reason: 'each request gets a fresh correlation id',
      );
      expect(
        seen.first!.length,
        lessThanOrEqualTo(64),
        reason: 'backend CorrelationIdFilter caps inbound ids at 64 chars',
      );
    });

    test('respects a caller-supplied correlation id', () async {
      final api = _client(
        MockClient((request) async {
          expect(request.headers['x-correlation-id'], 'client-owns-this');
          return _json({'success': true, 'data': null}, 200);
        }),
      );

      await api.get<Object?>(
        '${ApiPaths.v1}/things',
        headers: {'X-Correlation-Id': 'client-owns-this'},
        dataParser: (d) => d,
      );
    });

    test('captures the backend echo on server errors', () async {
      final api = _client(
        MockClient((_) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'TASK_NOT_FOUND', 'message': 'Task not found'},
            }),
            404,
            headers: {
              'content-type': 'application/json',
              'x-correlation-id': 'server-trace-123',
            },
          );
        }),
      );

      await expectLater(
        api.get<Object?>('${ApiPaths.v1}/tasks/nope', dataParser: (d) => d),
        throwsA(
          isA<ApiException>().having(
            (e) => e.correlationId,
            'correlationId',
            'server-trace-123',
          ),
        ),
      );
    });
  });

  group('ApiClient — interceptors', () {
    test(
      'interceptors can inject headers before the request is sent',
      () async {
        final api = _client(
          MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer injected');
            return _json({
              'success': true,
              'data': {'ok': 1},
            }, 200);
          }),
          interceptors: [
            _HeaderInterceptor('authorization', 'Bearer injected'),
          ],
        );

        await api.get<Map<String, dynamic>>(
          '${ApiPaths.v1}/me',
          dataParser: _parseData,
        );
      },
    );

    test('interceptors observe responses and errors', () async {
      final events = <String>[];
      final observer = _RecordingInterceptor(events);
      final failing = _client(
        MockClient((_) async => http.Response('nope', 502)),
        interceptors: [observer],
      );

      await expectLater(
        failing.get<Object?>('/boom', dataParser: (d) => d),
        throwsA(isA<ApiException>()),
      );
      expect(events, ['request', 'response', 'error']);

      final ok = _client(
        MockClient((_) async => _json({'success': true, 'data': null}, 200)),
        interceptors: [observer],
      );
      await ok.get<Object?>('/fine', dataParser: (d) => d);
      expect(events, ['request', 'response', 'error', 'request', 'response']);
    });
  });
}

class _HeaderInterceptor extends ApiInterceptor {
  _HeaderInterceptor(this.header, this.value);

  final String header;
  final String value;

  @override
  Future<void> onRequest(ApiRequestData request) async {
    request.headers[header] = value;
  }
}

class _RecordingInterceptor extends ApiInterceptor {
  _RecordingInterceptor(this.events);

  final List<String> events;

  @override
  Future<void> onRequest(ApiRequestData request) async {
    events.add('request');
  }

  @override
  Future<void> onResponse(
    ApiRequestData request,
    ApiResponseData response,
  ) async {
    events.add('response');
  }

  @override
  Future<void> onError(ApiRequestData request, Object error) async {
    events.add('error');
  }
}

/// An [http.BaseClient] that completes the request with headers immediately but
/// never finishes streaming the body (the caller keeps [body] open with no
/// events), exercising the body-read timeout in `ApiClient` (see the
/// "stalls mid-body" test).
class _StallingBodyClient extends http.BaseClient {
  _StallingBodyClient(this.body);

  final StreamController<List<int>> body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      body.stream,
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
