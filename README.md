# ghmera_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Auth Setup

This app now uses real Firebase Authentication for Google, Apple, and Phone.

Before running on devices, complete these setup steps:

1. Create a Firebase project and add Android and iOS apps.
2. Enable these providers in Firebase Console -> Authentication -> Sign-in method:
	- Google
	- Apple
	- Phone
3. Add platform config files:
	- `android/app/google-services.json`
	- `ios/Runner/GoogleService-Info.plist`
4. Run `flutterfire configure` (recommended) to generate `firebase_options.dart`.
5. For Apple sign-in, enable "Sign in with Apple" capability in Xcode for the iOS target.
6. For iOS phone auth testing, ensure APNs and required URL schemes are configured in the Firebase iOS setup.

## Workflow API Backend

Help-request workflow mutations now go through a Python Firebase Functions HTTPS endpoint named `workflow_api`.

Deploy the backend with:

```bash
firebase deploy --only functions
```

By default, the Flutter app calls:

```text
https://us-central1-<firebase-project-id>.cloudfunctions.net/workflow_api
```

The project ID is read from `firebase_options.dart`.

If you need to point the app at a different deployed endpoint, pass a Dart define when running the app:

```bash
flutter run --dart-define=GHMERA_WORKFLOW_API_URL=https://<your-url>/workflow_api
```

You can also override the function region if needed:

```bash
flutter run --dart-define=GHMERA_FUNCTIONS_REGION=<region>
```
