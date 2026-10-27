#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build-deps
fetch() {
  local name="$1" url="$2" ref="$3"
  if [ ! -d ".build-deps/$name/.git" ]; then
    git init -q ".build-deps/$name"
    git -C ".build-deps/$name" remote add origin "$url"
  fi
  git -C ".build-deps/$name" fetch --depth 1 origin "$ref"
  git -C ".build-deps/$name" checkout --detach FETCH_HEAD
}
fetch engine https://github.com/RSDKModding/RSDKv4-Decompilation.git a7f5195e21fdad7b75e4587e249013feeea9e6f3
git -C .build-deps/engine submodule update --init --depth 1 dependencies/all/stb-image dependencies/all/tinyxml2
fetch SDL2 https://github.com/libsdl-org/SDL.git 5d249570393f7a37e037abf22cd6012a4cc56a71
fetch ogg https://github.com/xiph/ogg.git e1774cd77f471443541596e09078e78fdc342e4f
fetch vorbis https://github.com/xiph/vorbis.git 0657aee69dec8508a0011f47f3b69d7538e9d262
python3 scripts/prepare-ios.py
