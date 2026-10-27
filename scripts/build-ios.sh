#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/fetch-deps.sh
cmake -S ios -B build-ios -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build build-ios --target SonicForever --parallel 4
app="build-ios/SonicForever.app"
test -x "$app/SonicForever"
cp -R build-resources "$app/ForeverResources"
# Ad-hoc signature; installation requires TrollStore or another compatible signer.
codesign --force --sign - "$app"
mkdir -p dist/Payload
rm -rf dist/Payload/SonicForever.app
cp -R "$app" dist/Payload/
(cd dist && zip -qry SonicForever-iOS.ipa Payload)
cp dist/SonicForever-iOS.ipa dist/SonicForever-iOS.tipa
