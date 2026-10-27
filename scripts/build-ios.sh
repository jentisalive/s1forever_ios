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
# Generate the iPhone and iPad home-screen icons from the supplied artwork.
# Explicit PNG icons also work with the Ninja bundle generator (no actool step).
for icon in 'AppIcon60x60@2x:120' 'AppIcon60x60@3x:180' 'AppIcon76x76:76' 'AppIcon76x76@2x:152' 'AppIcon83.5x83.5@2x:167'; do
  name="${icon%:*}"
  size="${icon##*:}"
  sips -z "$size" "$size" ios/Assets/AppIcon.png --out "$app/$name.png" >/dev/null
done
# Ad-hoc signature; installation requires TrollStore or another compatible signer.
codesign --force --sign - "$app"
mkdir -p dist/Payload
rm -rf dist/Payload/SonicForever.app
cp -R "$app" dist/Payload/
(cd dist && zip -qry SonicForever-iOS.ipa Payload)
cp dist/SonicForever-iOS.ipa dist/SonicForever-iOS.tipa
