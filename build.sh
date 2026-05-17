#!/usr/bin/env bash
set -euo pipefail

# NOVA build script — Swift Command Line Tools 単体でビルド可能
# Usage:
#   ./build.sh         # ビルドして build/NOVA.app を生成
#   ./build.sh run     # ビルド後に起動
#   ./build.sh clean   # ビルド成果物を削除

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/NOVA.app"
ICON_SRC="$ROOT/NOVA/AppIcon.icns"

clean() {
    echo "🧹 build/ を削除中..."
    rm -rf "$ROOT/build"
}

generate_icon() {
    if [ -f "$ICON_SRC" ]; then return; fi
    if [ ! -f "$ROOT/make_icon.swift" ]; then
        echo "⚠️  make_icon.swift も AppIcon.icns も無いためアイコン生成をスキップ"
        return
    fi
    echo "🎨 アイコン生成中..."
    local png=/tmp/nova_icon_1024.png
    local iconset=/tmp/NOVA.iconset
    xcrun swift "$ROOT/make_icon.swift" "$png"
    rm -rf "$iconset"; mkdir -p "$iconset"
    sips -z 16 16     "$png" --out "$iconset/icon_16x16.png"     >/dev/null
    sips -z 32 32     "$png" --out "$iconset/icon_16x16@2x.png"  >/dev/null
    sips -z 32 32     "$png" --out "$iconset/icon_32x32.png"     >/dev/null
    sips -z 64 64     "$png" --out "$iconset/icon_32x32@2x.png"  >/dev/null
    sips -z 128 128   "$png" --out "$iconset/icon_128x128.png"   >/dev/null
    sips -z 256 256   "$png" --out "$iconset/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$png" --out "$iconset/icon_256x256.png"   >/dev/null
    sips -z 512 512   "$png" --out "$iconset/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$png" --out "$iconset/icon_512x512.png"   >/dev/null
    cp "$png" "$iconset/icon_512x512@2x.png"
    iconutil -c icns "$iconset" -o "$ICON_SRC"
    rm -rf "$iconset" "$png"
}

build() {
    # Check VLCKit
    if [ ! -d "$ROOT/Frameworks/VLCKit.xcframework" ]; then
        cat <<EOF
❌ VLCKit.xcframework が見つかりません

   1. https://download.videolan.org/pub/cocoapods/prod/ から最新の
      VLCKit-3.x.x-*.tar.xz をダウンロード
   2. tar -xJf VLCKit-*.tar.xz
   3. 中の VLCKit.xcframework を $ROOT/Frameworks/ にコピー

EOF
        exit 1
    fi

    generate_icon

    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

    local arch
    arch="$(uname -m)"
    local target="${arch}-apple-macos13.0"

    echo "🔨 Swift コンパイル中... (target: $target)"
    xcrun --sdk macosx swiftc \
        "$ROOT/NOVA/"*.swift \
        -parse-as-library \
        -target "$target" \
        -F "$ROOT/Frameworks/VLCKit.xcframework/macos-arm64_x86_64" \
        -framework VLCKit \
        -framework AVFoundation \
        -framework AVKit \
        -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
        -O \
        -o "$APP/Contents/MacOS/NOVA"

    echo "📦 リソース配置..."
    cp "$ROOT/NOVA/Info.plist" "$APP/Contents/Info.plist"
    plutil -replace CFBundleExecutable -string "NOVA" "$APP/Contents/Info.plist"
    plutil -replace CFBundleIdentifier -string "com.example.Nova" "$APP/Contents/Info.plist"
    plutil -replace CFBundleName -string "NOVA" "$APP/Contents/Info.plist"
    [ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.icns"
    cp -R "$ROOT/Frameworks/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework" \
        "$APP/Contents/Frameworks/"

    echo "🔐 ad-hoc 署名..."
    codesign --force --deep --sign - "$APP/Contents/Frameworks/VLCKit.framework" >/dev/null
    codesign --force --deep --sign - --entitlements "$ROOT/NOVA/Nova.entitlements" "$APP" >/dev/null

    echo "🔄 Launch Services / Finder アイコンキャッシュ更新..."
    touch "$APP"
    local lsreg=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
    "$lsreg" -f -r "$APP" >/dev/null 2>&1 || true
    "$lsreg" -kill -domain local -domain user >/dev/null 2>&1 || true
    "$lsreg" -seed -r "$APP" >/dev/null 2>&1 || true

    local size
    size=$(du -sh "$APP" | cut -f1)
    echo "✅ 完了: $APP  ($size)"
}

run() {
    open "$APP"
    echo "🚀 NOVA を起動しました"
}

case "${1:-build}" in
    clean) clean ;;
    run)   build; run ;;
    build) build ;;
    *)     echo "Usage: $0 [build|run|clean]"; exit 1 ;;
esac
