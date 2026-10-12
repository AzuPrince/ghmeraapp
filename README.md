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

This app uses Firebase email/password authentication. New accounts are created
only after the user enters the 6-digit code sent to their email, and forgotten
passwords are reset with the same code-based flow.

Before running on devices, complete these setup steps:

1. Create a Firebase project and add Android and iOS apps.
2. Enable Email/Password in Firebase Console -> Authentication -> Sign-in method.
3. Add platform config files:
	- `android/app/google-services.json`
	- `ios/Runner/GoogleService-Info.plist`
4. Run `flutterfire configure` (recommended) to generate `firebase_options.dart`.
5. Copy `functions/.env.example` to `functions/.env` for local development and
   put `SMTP_PASSWORD=...` in `functions/.secret.local`. Both local files are
   ignored by Git.
6. Store the production SMTP password in Firebase Secret Manager before deploy:

```bash
firebase functions:secrets:set SMTP_PASSWORD
```

The configured mail server is `mail.peatechservice.com:465` with SSL, the SMTP
username is `info@peatechservice.com`, and messages are sent as
`PEATECH SERVICES LLC <mail@peatechservice.com>`.

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

## App Store Connect (iOS)

Bundle ID: `com.peatech.ghmera`  
Display name: **Ghmera**  
Apple team: `5FA87UK5LY`

### Build and upload

1. Bump the build number in `pubspec.yaml` (the `+` suffix must be higher than the last build uploaded to App Store Connect).
2. Build the IPA:

```bash
./scripts/ios_app_store_release.sh
```

3. Upload `build/ios/ipa/*.ipa` with [Transporter](https://apps.apple.com/us/app/transporter/id1450874784) or Xcode Organizer.

### After upload

In [App Store Connect](https://appstoreconnect.apple.com/):

1. Open the **Ghmera** app (create it with bundle ID `com.peatech.ghmera` if it does not exist).
2. Attach the new build under **TestFlight** or **App Store** → version **1.0.1**.
3. Complete **App Privacy**, screenshots, description, support URL, and review notes.
4. Enable **Sign in with Apple** if the capability is required (entitlements already include it).
5. Submit for review.

Export compliance: `ITSAppUsesNonExemptEncryption` is `false` in `ios/Runner/Info.plist` (standard encryption only).
