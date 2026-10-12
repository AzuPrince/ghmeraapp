#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-flutter}"
EXPORT_PLIST="${EXPORT_PLIST:-ios/ExportOptions-AppStore.plist}"

echo "==> Resolving Flutter dependencies"
"$FLUTTER" pub get

echo "==> Building App Store archive and IPA"
"$FLUTTER" build ipa --export-options-plist="$EXPORT_PLIST"

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "${IPA_PATH}" ]]; then
  echo "No IPA found under build/ios/ipa" >&2
  exit 1
fi

echo ""
echo "IPA ready: $IPA_PATH"
echo ""
echo "Upload options:"
echo "  1. Apple Transporter (drag the IPA onto the app)"
echo "  2. Xcode → Window → Organizer → Archives → Distribute App"
echo "  3. xcrun altool --upload-app --type ios -f \"$IPA_PATH\" --apiKey KEY --apiIssuer ISSUER_ID"
