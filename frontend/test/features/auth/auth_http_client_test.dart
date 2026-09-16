import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_app/features/auth/domain/auth_models.dart';
import 'package:todo_app/features/auth/presentation/auth_http_client.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('AuthenticatedHttpClient', () {
    test(
      'injects the bearer token on protected requests but not public ones',
      () async {
        final seen = <({String path, String? auth, String? marker})>[];
        final server = MockClient((request) async {
          seen.add((
            path: request.url.path,
            auth: request.headers['Authorization'],
            marker: request.headers['x-auth-retried'],
          ));
          if (request.url.path.endsWith('/auth/login')) {
            return _json({
              'success': true,
              'data': {
                'accessToken': 'access-1',
                'refreshToken': 'refresh-1',
                'tokenType': 'Bearer',
              },
            }, 200);
          }
          if (request.url.path.endsWith('/auth/me')) {
            return _json({
              'success': true,
              'data': {
                'userId': 'u1',
                'username': 'ada',
                'email': 'ada@example.com',
              },
            }, 200);
          }
          return _json({'success': true, 'data': null}, 200);
        });

        final auth = AuthState(httpClient: server);
        addTearDown(auth.dispose);
        await auth.login(username: 'ada', password: 'password123');

        final transport = AuthenticatedHttpClient(
          authState: auth,
          inner: server,
        );

        final protected = await transport.send(
          http.Request('GET', Uri.parse('http://test.local/api/v1/things')),
        );
        expect(protected.statusCode, 200);
        expect(seen.last.auth, 'Bearer access-1');

        final public = await transport.send(
          http.Request(
            'POST',
            Uri.parse('http://test.local/api/v1/auth/login'),
          ),
        );
        expect(public.statusCode, 200);
        expect(seen.last.auth, isNull);
      },
    );

    test('refreshes once and retries a 401 with the fresh token', () async {
      var protectedCalls = 0;
      var refreshCalls = 0;
      final seenAuth = <String?>[];

      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return _json({
            'success': true,
            'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'},
          }, 200);
        }
        if (path.endsWith('/auth/me')) {
          return _json({
            'success': true,
            'data': {
              'userId': 'u1',
              'username': 'ada',
              'email': 'ada@example.com',
            },
          }, 200);
        }
        if (path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return _json({
            'success': true,
            'data': {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
          }, 200);
        }
        if (path.endsWith('/protected')) {
          protectedCalls++;
          seenAuth.add(request.headers['Authorization']);
          if (protectedCalls == 1) {
            expect(request.headers['x-auth-retried'], isNull);
          }
          return protectedCalls == 1
              ? _json({
                  'success': false,
                  'error': {'code': 'AUTHENTICATION_FAILED'},
                }, 401)
              : _json({
                  'success': true,
                  'data': {'ok': true},
                }, 200);
        }
        return _json({'success': true, 'data': null}, 200);
      });

      final auth = AuthState(httpClient: server);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      final transport = AuthenticatedHttpClient(authState: auth, inner: server);
      final response = await transport.send(
        http.Request('GET', Uri.parse('http://test.local/api/v1/protected')),
      );

      expect(response.statusCode, 200);
      expect(protectedCalls, 2);
      expect(refreshCalls, 1);
      expect(seenAuth, ['Bearer access-1', 'Bearer access-2']);
    });

    test('never refreshes twice for the same request (loop guard)', () async {
      var protectedCalls = 0;
      var refreshCalls = 0;
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return _json({
            'success': true,
            'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'},
          }, 200);
        }
        if (path.endsWith('/auth/me')) {
          return _json({
            'success': true,
            'data': {
              'userId': 'u1',
              'username': 'ada',
              'email': 'ada@example.com',
            },
          }, 200);
        }
        if (path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return _json({
            'success': true,
            'data': {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
          }, 200);
        }
        if (path.endsWith('/stubborn')) {
          protectedCalls++;
          return _json({
            'success': false,
            'error': {'code': 'AUTHENTICATION_FAILED'},
          }, 401);
        }
        return _json({'success': true, 'data': null}, 200);
      });

      final auth = AuthState(httpClient: server);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      final transport = AuthenticatedHttpClient(authState: auth, inner: server);
      final response = await transport.send(
        http.Request('GET', Uri.parse('http://test.local/api/v1/stubborn')),
      );

      expect(response.statusCode, 401);
      expect(protectedCalls, 2);
      expect(refreshCalls, 1, reason: 'the retried 401 must not refresh again');
    });

    test('clears the session and returns the 401 when refresh fails', () async {
      var protectedCalls = 0;
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return _json({
            'success': true,
            'data': {
              'accessToken': 'access-1',
              'refreshToken': 'refresh-expired',
            },
          }, 200);
        }
        if (path.endsWith('/auth/me')) {
          return _json({
            'success': true,
            'data': {
              'userId': 'u1',
              'username': 'ada',
              'email': 'ada@example.com',
            },
          }, 200);
        }
        if (path.endsWith('/auth/refresh')) {
          return _json({
            'success': false,
            'error': {'code': 'REFRESH_TOKEN_INVALID'},
          }, 401);
        }
        if (path.endsWith('/protected')) {
          protectedCalls++;
          return _json({
            'success': false,
            'error': {'code': 'AUTHENTICATION_FAILED'},
          }, 401);
        }
        return _json({'success': true, 'data': null}, 200);
      });

      final auth = AuthState(httpClient: server);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      final transport = AuthenticatedHttpClient(authState: auth, inner: server);
      final response = await transport.send(
        http.Request('GET', Uri.parse('http://test.local/api/v1/protected')),
      );

      expect(response.statusCode, 401);
      expect(protectedCalls, 1, reason: 'no retry without a fresh refresh');
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.accessToken, isNull);
    });

    test('auth register/refresh/logout never receive the bearer header or '
        'a 401-refresh retry', () async {
      var refreshCalls = 0;
      final seenAuth = <String?>[];
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return _json({
            'success': true,
            'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'},
          }, 200);
        }
        if (path.endsWith('/auth/me')) {
          return _json({
            'success': true,
            'data': {
              'userId': 'u1',
              'username': 'ada',
              'email': 'ada@example.com',
            },
          }, 200);
        }
        seenAuth.add(request.headers['Authorization']);
        return _json({
          'success': false,
          'error': {'code': 'SERVER_ERROR'},
        }, 401);
      });

      final auth = AuthState(httpClient: server);
      addTearDown(auth.dispose);
      await auth.login(username: 'ada', password: 'password123');

      final transport = AuthenticatedHttpClient(authState: auth, inner: server);
      for (final path in [
        '/api/v1/auth/register',
        '/api/v1/auth/refresh',
        '/api/v1/auth/logout',
      ]) {
        final response = await transport.send(
          http.Request('POST', Uri.parse('http://test.local$path')),
        );
        expect(response.statusCode, 401);
      }

      expect(seenAuth, [
        null,
        null,
        null,
      ], reason: 'no bearer header on any public auth path');
      expect(refreshCalls, 0, reason: 'a public 401 must never refresh');
    });

    test(
      'concurrent 401s share one refresh and each request retries once',
      () async {
        var protectedCalls = 0;
        var refreshCalls = 0;
        final seenAuth = <String?>[];
        final server = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login')) {
            return _json({
              'success': true,
              'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'},
            }, 200);
          }
          if (path.endsWith('/auth/me')) {
            return _json({
              'success': true,
              'data': {
                'userId': 'u1',
                'username': 'ada',
                'email': 'ada@example.com',
              },
            }, 200);
          }
          if (path.endsWith('/auth/refresh')) {
            refreshCalls++;
            // Hold the rotation open so both callers observe the same
            // in-flight refresh instead of starting a second one.
            await Future.delayed(const Duration(milliseconds: 25));
            return _json({
              'success': true,
              'data': {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
            }, 200);
          }
          if (path.endsWith('/shared')) {
            protectedCalls++;
            seenAuth.add(request.headers['Authorization']);
            final retried = request.headers['x-auth-retried'] == 'true';
            return retried
                ? _json({
                    'success': true,
                    'data': {'ok': true},
                  }, 200)
                : _json({
                    'success': false,
                    'error': {'code': 'AUTHENTICATION_FAILED'},
                  }, 401);
          }
          return _json({'success': true, 'data': null}, 200);
        });

        final auth = AuthState(httpClient: server);
        addTearDown(auth.dispose);
        await auth.login(username: 'ada', password: 'password123');

        final transport = AuthenticatedHttpClient(
          authState: auth,
          inner: server,
        );

        final responses = await Future.wait([
          transport.send(
            http.Request('GET', Uri.parse('http://test.local/api/v1/shared')),
          ),
          transport.send(
            http.Request('GET', Uri.parse('http://test.local/api/v1/shared')),
          ),
        ]);

        expect(responses.map((r) => r.statusCode), [200, 200]);
        expect(
          refreshCalls,
          1,
          reason: 'concurrent 401s share one in-flight refresh',
        );
        expect(
          protectedCalls,
          4,
          reason: 'each request fails once then retries once',
        );
        expect(seenAuth.where((h) => h != null).length, 4);
        expect(seenAuth, contains('Bearer access-2'));
      },
    );

    test(
      'health endpoints stay public: no bearer header and no 401-refresh retry',
      () async {
        var refreshCalls = 0;
        var healthCalls = 0;
        final seenAuth = <String?>[];
        final server = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login')) {
            return _json({
              'success': true,
              'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'},
            }, 200);
          }
          if (path.endsWith('/auth/me')) {
            return _json({
              'success': true,
              'data': {
                'userId': 'u1',
                'username': 'ada',
                'email': 'ada@example.com',
              },
            }, 200);
          }
          if (path.endsWith('/auth/refresh')) {
            refreshCalls++;
            return _json({
              'success': true,
              'data': {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
            }, 200);
          }
          if (path.startsWith('/api/v1/health')) {
            healthCalls++;
            seenAuth.add(request.headers['Authorization']);
            return _json({
              'success': false,
              'error': {'code': 'AUTHENTICATION_FAILED'},
            }, 401);
          }
          return _json({'success': true, 'data': null}, 200);
        });

        final auth = AuthState(httpClient: server);
        addTearDown(auth.dispose);
        await auth.login(username: 'ada', password: 'password123');

        final transport = AuthenticatedHttpClient(
          authState: auth,
          inner: server,
        );
        for (final path in ['/api/v1/health', '/api/v1/health/readiness']) {
          final response = await transport.send(
            http.Request('GET', Uri.parse('http://test.local$path')),
          );
          expect(response.statusCode, 401);
        }

        expect(healthCalls, 2);
        expect(seenAuth, [null, null], reason: 'no bearer on public health');
        expect(refreshCalls, 0, reason: 'a public 401 must never refresh');
      },
    );
  });
}
