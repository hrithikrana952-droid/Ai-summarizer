#!/bin/bash
set -e

APP_NAME="ConversationAgent"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Creating App Bundle Structure..."
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

echo "Copying Info.plist..."
cp Sources/Info.plist "${CONTENTS}/Info.plist"

echo "Compiling Swift Sources..."
swiftc Sources/*.swift -o "${MACOS}/${APP_NAME}"

echo "Signing the App Bundle with entitlements..."
codesign -s "ConversationAgentSign" --deep -f --entitlements Entitlements.plist "${APP_BUNDLE}"

echo "Build Successful: ${APP_BUNDLE}"
echo ""
echo "To install permanently, run:"
echo "  sudo cp -R ${APP_BUNDLE} /Applications/ && open /Applications/${APP_BUNDLE}"
