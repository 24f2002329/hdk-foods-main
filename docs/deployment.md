# Deployment & Environment Configuration

This document provides deployment runbooks, CLI flags, and launch configurations for the HDK Foods ecosystem.

---

## 1. Django Backend Setup

### Prerequisites
* Python 3.12+
* PostgreSQL
* Redis (for Django Channels WebSockets)

### Commands
```bash
# Navigate to backend
cd backend/

# Install dependencies (virtualenv)
pip install -r requirements.txt

# Run database migrations
python manage.py migrate

# Start the development server
python manage.py runserver

# Run backend unit & integration tests
python manage.py test
```

---

## 2. Flutter Apps Configuration

The Flutter client applications (`frontend`, `frontend_admin`, `frontend_delivery`) resolve configurations dynamically at build time using the `--dart-define` option.

### Active Environment (`ENV`)
Tells the application which API endpoints and Firebase configurations to load.
* **Options**: `dev`, `staging`, `prod`
* **Default**: `dev`
* **Example**:
  ```bash
  flutter run --dart-define=ENV=prod
  ```

### Development API Override (`DEV_API_URL`)
Overrides the default `localhost:8000` API url, useful when debugging on physical devices over local networks.
* **Example**:
  ```bash
  flutter run --dart-define=DEV_API_URL=http://192.168.1.50:8000/api
  ```

### Google Maps API Key (`GOOGLE_MAPS_API_KEY`)
Required for loading Google Maps SDK in the Customer and Admin apps.
* **Example**:
  ```bash
  flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSy...
  ```

---

## 3. Flutter Build Commands

To build release packages for distribution:

### Android Release Build
```bash
# Build production bundle
flutter build appbundle --release \
  --dart-define=ENV=prod \
  --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyYOURKEY

# Build staging APK
flutter build apk --release \
  --dart-define=ENV=staging \
  --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyYOURKEY
```

### iOS Release Build
```bash
flutter build ipa --release \
  --dart-define=ENV=prod \
  --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyYOURKEY
```
