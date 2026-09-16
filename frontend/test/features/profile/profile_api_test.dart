import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/api/api_client.dart';
import 'package:todo_app/data/api/api_exception.dart';
import 'package:todo_app/features/profile/data/profile_api.dart';

import '../../support/mock_api.dart';

const _base = 'http://test.local';

void main() {
  ProfileApi api(MockApiServer server) =>
      ProfileApi(ApiClient(baseUrl: _base, httpClient: server.client));

  group('ProfileApi', () {
    test('getProfile parses the profile payload', () async {
      final server = MockApiServer();
      final profile = await api(server).getProfile();

      expect(profile.userId, 'user-1');
      expect(profile.firstName, 'Ada');
      expect(profile.lastName, 'Lovelace');
      expect(profile.displayName, 'Ada Lovelace');
      expect(profile.timezone, 'Europe/London');
      expect(profile.profileImageUrl, 'https://example.com/ada.png');
      expect(profile.version, 1);
      expect(server.profileGetCalls, 1);
    });

    test('getProfile throws PROFILE_NOT_FOUND on a 404', () async {
      final server = MockApiServer(behavior: Behavior(profileNotFound: true));
      await expectLater(
        api(server).getProfile(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'PROFILE_NOT_FOUND')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('updateProfile sends a full PUT body', () async {
      final server = MockApiServer();
      final profile = await api(server).updateProfile(
        const ProfileUpdateRequest(
          firstName: 'Grace',
          lastName: 'Hopper',
          displayName: 'Grace',
          timezone: 'America/New_York',
          profileImageUrl: null,
        ),
      );

      expect(profile.firstName, 'Ada');
      expect(server.profilePutCalls, 1);
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'firstName',
        'lastName',
        'displayName',
        'timezone',
        'profileImageUrl',
      });
      expect(body['firstName'], 'Grace');
      expect(body['profileImageUrl'], isNull);
    });

    test('patchProfile sends only the changed fields', () async {
      final server = MockApiServer();
      final profile = await api(server).patchProfile(
        const ProfilePatchRequest({
          'displayName': 'A.L.',
          'profileImageUrl': null,
        }),
      );

      expect(profile.displayName, 'Ada Lovelace');
      expect(server.profilePatchCalls, 1);
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'displayName', 'profileImageUrl'});
      expect(body['displayName'], 'A.L.');
      expect(body['profileImageUrl'], isNull);
    });

    test('patchProfile omits untouched fields entirely', () async {
      final server = MockApiServer();
      await api(server)
          .patchProfile(const ProfilePatchRequest({'firstName': 'Grace'}));
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'firstName'});
      expect(body.containsKey('timezone'), isFalse);
    });
  });
}
