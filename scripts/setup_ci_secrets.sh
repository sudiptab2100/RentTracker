#!/usr/bin/env bash
# Sets the GitHub Actions secrets used by .github/workflows/build-apk.yml.
# Prereqs: `gh auth login` (authenticated), run from the repo root.
set -euo pipefail

REPO="${1:-sudiptab2100/RentTracker}"
GS="android/app/google-services.json"
KS="$HOME/.android/debug.keystore"

[ -f "$GS" ] || { echo "Missing $GS (run: flutterfire configure)"; exit 1; }
[ -f "$KS" ] || { echo "Missing $KS (build once with: flutter build apk --debug)"; exit 1; }

echo "Setting GOOGLE_SERVICES_JSON on $REPO ..."
base64 < "$GS" | gh secret set GOOGLE_SERVICES_JSON --repo "$REPO"

echo "Setting DEBUG_KEYSTORE_BASE64 on $REPO ..."
base64 < "$KS" | gh secret set DEBUG_KEYSTORE_BASE64 --repo "$REPO"

echo "Done. Push a tag to build & publish, e.g.:  git tag v1.0.0 && git push origin v1.0.0"
