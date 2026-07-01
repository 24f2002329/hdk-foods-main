import 'environment.dart';

class AppConfig {
  static Environment get environment {
    const String envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (envString.toLowerCase()) {
      case 'prod':
      case 'production':
        return Environment.prod;
      case 'staging':
        return Environment.staging;
      case 'dev':
      case 'development':
      default:
        return Environment.dev;
    }
  }

  static bool get isDev => environment == Environment.dev;
  static bool get isStaging => environment == Environment.staging;
  static bool get isProd => environment == Environment.prod;
}
