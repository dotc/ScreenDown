#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="$PWD/build/ScreenDown.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -O Sources/EventLog.swift Sources/Shared.swift Sources/Helper/main.swift -o "$app/Contents/Resources/ScreenDownHelper" -framework IOKit
swiftc -O Sources/EventLog.swift Sources/Shared.swift Sources/Localization.swift Sources/AppIcon.swift Sources/App/main.swift -o "$app/Contents/MacOS/ScreenDown" -framework AppKit -framework IOKit
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
codesign --force --sign - "$app/Contents/Resources/ScreenDownHelper"
codesign --force --sign - "$app"
"$app/Contents/Resources/ScreenDownHelper" --self-test
printf 'Built %s\n' "$app"
