#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=YouTube.app
DEPLOYMENT_TARGET=12.0
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp YouTube.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>YouTube</string>
    <key>CFBundleIdentifier</key><string>local.youtube.wrapper</string>
    <key>CFBundleExecutable</key><string>YouTube</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>YouTube</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>$DEPLOYMENT_TARGET</string>
</dict></plist>
EOF
# Compile each architecture, then merge into one universal binary.
# -runtime-compatibility-version none skips the Swift back-deployment shims,
# whose x86_64 slices the Command Line Tools don't ship (full Xcode does).
BIN="$APP/Contents/MacOS/YouTube"
for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macosx$DEPLOYMENT_TARGET" \
        -runtime-compatibility-version none \
        main.swift -o "$BIN.$arch"
done
lipo -create -output "$BIN" "$BIN.arm64" "$BIN.x86_64"
rm "$BIN.arm64" "$BIN.x86_64"
codesign --force --sign - "$APP"
echo "Built $APP ($(lipo -archs "$BIN"))"
