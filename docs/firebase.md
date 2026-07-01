# Firebase Integration

This document details the Firebase infrastructure, target configurations, and dynamic options resolution.

---

## 1. Centralized Firebase Configuration

To prevent separate copies of `firebase_options.dart` across all client apps, all options are centralize-managed under `packages/hdk_core/lib/config/firebase_config.dart`.

### Dynamic Resolution
The initialization sequence uses `FirebaseConfig.options` to determine the correct API keys, project IDs, and messaging sender IDs:

```dart
// main.dart (Across Customer, Admin, and Delivery applications)
await Firebase.initializeApp(
  options: FirebaseConfig.options,
);
```

The options resolve based on the active platform (`Android`, `iOS`, `Web`) and the compile-time environment (`ENV` define flag).

---

## 2. Platform Configurations

While option properties are resolved in Dart, native SDKs require configuration files to be in place in their respective platform directories for deep-linking, APNs certificates, and push receiver registrations:

### Android (`android/app/`)
* **File**: `google-services.json`
* **Path**: `android/app/src/google-services.json`
* **Configuration**: Contains the client IDs, package names (`com.hdkfoods.frontend`), and database URLs.

### iOS (`ios/Runner/`)
* **File**: `GoogleService-Info.plist`
* **Path**: `ios/Runner/GoogleService-Info.plist`
* **Configuration**: Contains the plist keys, reverse client IDs, and bundle identifier matches.

---

## 3. Dynamic App Environments

Each environment resolves to corresponding target configurations within `FirebaseConfig`:

* **`dev` / default**: Target sandbox project for local developer testing.
* **`staging`**: Staging Firebase project containing push certificates for testing push notification deliveries on TestFlight/Firebase App Distribution.
* **`prod`**: Production Firebase project for active customer notifications and live transactions.
