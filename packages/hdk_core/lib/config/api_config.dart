import 'app_config.dart';
import 'environment.dart';

class ApiConfig {
  static String get baseUrl {
    switch (AppConfig.environment) {
      case Environment.prod:
        return "https://api.hdkfoods.in/api/v1";
      case Environment.staging:
        return "https://staging-api.hdkfoods.in/api/v1";
      case Environment.dev:
        return const String.fromEnvironment(
          'DEV_API_URL',
          defaultValue: "http://localhost:8000/api/v1",
        );
    }
  }

  static String get wsBaseUrl {
    switch (AppConfig.environment) {
      case Environment.prod:
        return "wss://api.hdkfoods.in";
      case Environment.staging:
        return "wss://staging-api.hdkfoods.in";
      case Environment.dev:
        final String devApi = const String.fromEnvironment(
          'DEV_API_URL',
          defaultValue: "",
        );
        if (devApi.isNotEmpty) {
          final Uri uri = Uri.parse(devApi);
          final String protocol = uri.scheme == 'https' ? 'wss' : 'ws';
          return "$protocol://${uri.host}:${uri.port}";
        }
        return "ws://localhost:8000";
    }
  }
}
