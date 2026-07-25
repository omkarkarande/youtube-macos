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
swiftc -O -target "$(uname -m)-apple-macosx$DEPLOYMENT_TARGET" \
    main.swift -o "$APP/Contents/MacOS/YouTube"
codesign --force --sign - "$APP"
echo "Built $APP"
