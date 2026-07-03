import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class HdkCrashlytics {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Set the user identifier to associate crashes with a specific user
  static Future<void> setUserIdentifier(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
      if (kDebugMode) {
        print('[HdkCrashlytics] User identifier set: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkCrashlytics] Error setting user identifier: $e');
      }
    }
  }

  /// Log a custom message to be sent with crash reports
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
      if (kDebugMode) {
        print('[HdkCrashlytics] Log: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkCrashlytics] Error logging message: $e');
      }
    }
  }

  /// Manually record a non-fatal error
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
      if (kDebugMode) {
        print('[HdkCrashlytics] Error recorded: $exception, fatal: $fatal');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkCrashlytics] Error recording exception: $e');
      }
    }
  }

  /// Add custom key-value pairs to the crash reports for debugging context
  static Future<void> setCustomKey(String key, Object value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('[HdkCrashlytics] Error setting custom key: $e');
      }
    }
  }
}
