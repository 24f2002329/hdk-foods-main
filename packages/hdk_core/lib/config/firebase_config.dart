import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';
import 'environment.dart';

class FirebaseConfig {
  static FirebaseOptions get options {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'FirebaseConfig has not been configured for this platform.',
        );
    }
  }

  static FirebaseOptions get web {
    switch (AppConfig.environment) {
      case Environment.prod:
      case Environment.staging:
      case Environment.dev:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDMqkCr6bP38Xu92-uDrHOacmfkl9kAF7E',
          appId: '1:215110053067:web:8d35cd11abb256fca2bf4e',
          messagingSenderId: '215110053067',
          projectId: 'hdk-foods',
          authDomain: 'hdk-foods.firebaseapp.com',
          storageBucket: 'hdk-foods.firebasestorage.app',
          measurementId: 'G-69F23N7P7N',
        );
    }
  }

  static FirebaseOptions get android {
    switch (AppConfig.environment) {
      case Environment.prod:
      case Environment.staging:
      case Environment.dev:
        return const FirebaseOptions(
          apiKey: 'AIzaSyCTCq8bGL_rQmrTml-_DKF4cLek3nGTJK4',
          appId: '1:215110053067:android:bce4c94dbf879ebba2bf4e',
          messagingSenderId: '215110053067',
          projectId: 'hdk-foods',
          storageBucket: 'hdk-foods.firebasestorage.app',
        );
    }
  }

  static FirebaseOptions get ios {
    switch (AppConfig.environment) {
      case Environment.prod:
      case Environment.staging:
      case Environment.dev:
        return const FirebaseOptions(
          apiKey: 'AIzaSyBEaf--IPdR4jvK-O-7fzVeyuMsrgc1Sc0',
          appId: '1:215110053067:ios:a8b74035ccfa02f1a2bf4e',
          messagingSenderId: '215110053067',
          projectId: 'hdk-foods',
          storageBucket: 'hdk-foods.firebasestorage.app',
          iosBundleId: 'com.hdkfoods.frontend',
        );
    }
  }
}
