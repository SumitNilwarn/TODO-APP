import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('defaults the API base URL to the local backend', () {
      expect(AppConfig.apiBaseUrl, 'http://localhost:8080');
    });

    test('defaults debug mode to true', () {
      expect(AppConfig.debugMode, isTrue);
    });

    test('defaults the environment name to development', () {
      expect(AppConfig.environment, 'development');
      expect(AppConfig.appEnvironment, AppEnvironment.development);
    });

    test('parses known and unknown environment names', () {
      expect(AppEnvironment.fromName('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('production'), AppEnvironment.production);
      expect(AppEnvironment.fromName('PRODUCTION'), AppEnvironment.production);
      expect(AppEnvironment.fromName(' random '), AppEnvironment.development);
      expect(AppEnvironment.fromName(''), AppEnvironment.development);
    });
  });
}
