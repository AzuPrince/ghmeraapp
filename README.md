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
