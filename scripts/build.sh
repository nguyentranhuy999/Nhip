#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --product Nhip --disable-sandbox --scratch-path .build
if [[ ! -f Resources/Nhip.icns || Resources/MakeIcon.swift -nt Resources/Nhip.icns ]]; then
    swift Resources/MakeIcon.swift "$PWD/.build"
    iconutil -c icns .build/Nhip.iconset -o Resources/Nhip.icns
fi
BUNDLE_STAGE="$(mktemp -d "${TMPDIR:-/tmp/}nhip-bundle.XXXXXX")"
trap 'rm -rf "$BUNDLE_STAGE"' EXIT
APP="$BUNDLE_STAGE/Nhip.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Nhip "$APP/Contents/MacOS/Nhip"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/Nhip.icns ]]; then cp Resources/Nhip.icns "$APP/Contents/Resources/Nhip.icns"; fi
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - --identifier vn.local.nhip "$APP"
codesign --verify --strict "$APP"
mkdir -p "$PWD/dist"
ditto --norsrc --noextattr "$APP" "$PWD/dist/Nhip.app"
print "Đã tạo: $PWD/dist/Nhip.app (đã kiểm tra chữ ký trước khi chép vào Desktop)"
