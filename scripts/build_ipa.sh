#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 清理舊建置產物..."
rm -rf build AppleMapsNavigator.ipa

echo "==> 使用 xcodebuild 編譯 Release iOS App (Sideload Ad-Hoc)..."
xcodebuild clean build \
  -project AppleMapsNavigator.xcodeproj \
  -target AppleMapsNavigator \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$ROOT_DIR/build" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES

echo "==> 套用 Ad-Hoc 簽章並打包 Payload 為 AppleMapsNavigator.ipa..."
mkdir -p build/ipa/Payload
cp -R build/Release-iphoneos/AppleMapsNavigator.app build/ipa/Payload/
codesign --force --deep --sign - build/ipa/Payload/AppleMapsNavigator.app
(cd build/ipa && zip -r "$ROOT_DIR/AppleMapsNavigator.ipa" Payload)

echo "==> 打包完成：$ROOT_DIR/AppleMapsNavigator.ipa"
ls -lh "$ROOT_DIR/AppleMapsNavigator.ipa"
