#!/bin/bash
# uninstall-opencode-service.sh
# 卸载 Finder 右键「OpenCode」服务

set -euo pipefail

SERVICE_DIR="$HOME/Library/Services/OpenCode.workflow"

echo "  Removing $SERVICE_DIR ..."
rm -rf "$SERVICE_DIR"

# 刷新服务注册缓存
if [ -x /System/Library/CoreServices/pbs ]; then
    /System/Library/CoreServices/pbs -flush 2>/dev/null || true
fi

# 重启 Finder 使其重新加载服务列表
killall Finder 2>/dev/null || true

echo ""
echo "  Done! 'OpenCode' service has been uninstalled."
