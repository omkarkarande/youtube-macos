#!/bin/sh
# Submit the built app to Apple's notary service, staple the ticket, and
# produce a distributable zip. Run ./build.sh first (with a Developer ID
# identity available, which is the default when one is in the keychain).
#
# One-time setup — store an app-specific password generated at account.apple.com
# (Sign-In and Security > App-Specific Passwords):
#   xcrun notarytool store-credentials notary \
#       --apple-id you@example.com --team-id YOURTEAMID
# (omit --password and it prompts, keeping the secret out of your shell history)
set -e
cd "$(dirname "$0")"
APP=YouTube.app
VERSION=0.2
PROFILE=${NOTARY_PROFILE:-notary}
ZIP="YouTube-macos-$VERSION.zip"

# Refuse to ship an ad-hoc build: notarization requires a Developer ID signature.
# -dvv, not -dv: Authority lines only print at verbosity 2 and above.
codesign -dvv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" || {
    echo "error: $APP is not Developer ID signed. Run ./build.sh first." >&2
    exit 1
}

# ditto, not zip: it preserves the code signature and bundle metadata.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

# Staple the ticket to the bundle so Gatekeeper clears it offline, then
# re-zip — the ticket lives in the .app, not in the submitted archive.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

spctl --assess --type execute --verbose=2 "$APP"
echo "Notarized and stapled: $ZIP"
