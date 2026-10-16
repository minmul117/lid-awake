#!/bin/bash
# LidAwake.app 빌드 → build/LidAwake.app
# 필요: Xcode Command Line Tools (없으면: xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc가 없습니다. 'xcode-select --install'로 Command Line Tools를 설치하세요." >&2
  exit 1
fi

VERSION="$(cat VERSION)"
APP="build/LidAwake.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "컴파일 중... (v$VERSION)"
swiftc -O Sources/*.swift \
  -o "$APP/Contents/MacOS/LidAwake" \
  -framework AppKit -framework IOKit -framework ServiceManagement

cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "완료: $APP"
