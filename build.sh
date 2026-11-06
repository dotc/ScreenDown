#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="$PWD/build/ScreenDown.app"
version="${VERSION:-0.4.0}"
build_number="${BUILD_NUMBER:-9}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must be X.Y.Z" >&2; exit 1; }
[[ "$build_number" =~ ^[0-9]+$ ]] || { echo "BUILD_NUMBER must be numeric" >&2; exit 1; }
read -r -a architectures <<< "${ARCHS:-$(uname -m)}"
compile_app_binary() {
    local output="$1"
    shift
    local slices=()
    local architecture
    for architecture in "${architectures[@]}"; do
        case "$architecture" in arm64|x86_64) ;; *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;; esac
        local slice="$output.$architecture"
        swiftc -O -target "$architecture-apple-macosx13.0" "$@" -o "$slice"
        slices+=("$slice")
    done
    lipo -create "${slices[@]}" -output "$output"
    rm -f "${slices[@]}"
}
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
compile_app_binary "$app/Contents/Resources/ScreenDownHelper" Sources/EventLog.swift Sources/Shared.swift Sources/Helper/main.swift -framework IOKit
compile_app_binary "$app/Contents/MacOS/ScreenDown" Sources/EventLog.swift Sources/Shared.swift Sources/Localization.swift Sources/AppIcon.swift Sources/App/main.swift -framework AppKit -framework IOKit
swiftc Sources/AppIcon.swift Scripts/IconGenerator/main.swift -o "$PWD/build/generate-icon" -framework AppKit
"$PWD/build/generate-icon" "$PWD/build/AppIcon.iconset"
iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp install.sh "$app/Contents/Resources/install.sh"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.screendown.app</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>CFBundleName</key><string>ScreenDown</string>
<key>CFBundleExecutable</key><string>ScreenDown</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>CFBundleVersion</key><string>9</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"
codesign --force --sign - "$app/Contents/Resources/ScreenDownHelper"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
"$app/Contents/Resources/ScreenDownHelper" --self-test
printf 'Built %s\n' "$app"
