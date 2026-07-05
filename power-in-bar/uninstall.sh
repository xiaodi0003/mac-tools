#!/bin/bash
set -euo pipefail

echo "==> Removing Login Item ..."
osascript -e "
tell application \"System Events\"
    set loginItems to every login item whose path is \"/Applications/PowerMonitor.app\"
    repeat with item in loginItems
        delete item
    end repeat
end tell
" 2>/dev/null && echo "    Done." || echo "    (none)"

echo "==> Stopping PowerMonitor ..."
killall PowerMonitor 2>/dev/null || echo "    (not running)"

echo "==> Removing /Applications/PowerMonitor.app ..."
rm -rf /Applications/PowerMonitor.app

echo "==> Removing /usr/local/bin/power ..."
rm -f /usr/local/bin/power

echo "✅ Uninstalled."
