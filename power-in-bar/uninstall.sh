#!/bin/bash
set -euo pipefail

echo "==> Stopping PowerMonitor ..."
killall PowerMonitor 2>/dev/null || echo "    (not running)"

echo "==> Removing /Applications/PowerMonitor.app ..."
rm -rf /Applications/PowerMonitor.app

echo "==> Removing /usr/local/bin/power ..."
rm -f /usr/local/bin/power

echo "✅ Uninstalled."
