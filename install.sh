#!/bin/bash
set -euo pipefail
mode="$1"
user_id="$2"
group_id="$3"
[[ "$user_id" =~ ^[0-9]+$ && "$group_id" =~ ^[0-9]+$ ]] || exit 2
label=local.screendown.helper
helper="/Library/PrivilegedHelperTools/$label"
plist="/Library/LaunchDaemons/$label.plist"
if [[ "$mode" == uninstall ]]; then
    launchctl bootout "system/$label" 2>/dev/null || true
    rm -f "$helper" "$plist"
    rm -rf /var/run/local.screendown
    exit 0
fi
[[ "$mode" == install ]] || exit 2
resources="$(cd "$(dirname "$0")" && pwd)"
launchctl bootout "system/$label" 2>/dev/null || true
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
install -o root -g wheel -m 755 "$resources/ScreenDownHelper" "$helper"
cat > "$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.screendown.helper</string>
<key>ProgramArguments</key><array><string>/Library/PrivilegedHelperTools/local.screendown.helper</string></array>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>10</integer>
</dict></plist>
PLIST
chown root:wheel "$plist"
chmod 644 "$plist"
launchctl bootstrap system "$plist"
