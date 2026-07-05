#!/bin/bash
# install-opencode-service.sh
# Install Finder 右键「OpenCode」服务
# 在 Terminal 中打开选中目录并启动 opencode

set -euo pipefail

SERVICE_DIR="$HOME/Library/Services/OpenCode.workflow"
CONTENTS_DIR="$SERVICE_DIR/Contents"

# ===================== 清理旧文件 =====================

rm -f "$CONTENTS_DIR/document.wflow"
rm -rf "$SERVICE_DIR"

# ===================== 创建目录 =====================

mkdir -p "$CONTENTS_DIR/Resources"

# ===================== Info.plist =====================

cat > "$CONTENTS_DIR/Info.plist" <<'INFO'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en_US</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.services.openCode</string>
    <key>CFBundleName</key>
    <string>OpenCode</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>OpenCode</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSApplicationIdentifier</key>
                <string>com.apple.finder</string>
            </dict>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
INFO

echo "  [+] Contents/Info.plist"

# ===================== document.wflow (via Python) =====================

/usr/bin/python3 <<'PYEOF'
import plistlib, uuid, os

service_dir = os.path.expanduser("~/Library/Services/OpenCode.workflow")
contents_dir = os.path.join(service_dir, "Contents")
resources_dir = os.path.join(contents_dir, "Resources")

COMMAND_STRING = (
    'for f in "$@"; do '
    'd="$(printf "%q" "$f")"; '
    'osascript -e "tell application \\"Terminal\\" to do script \\"cd $d && exec bash -l -c opencode\\""; '
    'done; '
    'osascript -e "tell application \\"Terminal\\" to activate"'
)

SOURCE = (
    '#!/bin/bash\n'
    'export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8\n'
    'for f in "$@"; do\n'
    '    d="$(printf "%q" "$f")"\n'
    '    osascript -e "tell application \\"Terminal\\" to do script \\"cd $d && exec bash -l -c opencode\\""\n'
    'done\n'
    'osascript -e "tell application \\"Terminal\\" to activate"'
)

wf = {
    'AMApplicationBuild': '307',
    'AMApplicationVersion': '2.2',
    'AMDocumentVersion': '2',
    'actions': [{
        'action': {
            'AMAccepts': {
                'Container': 'List',
                'Optional': True,
                'Types': ['public.folder'],
            },
            'AMActionVersion': '2.0.3',
            'AMParameterProperties': {
                'COMMAND_STRING': {},
                'CheckedForUserDefaultShell': {},
                'inputMethod': {},
                'shell': {},
                'source': {},
            },
            'AMProvides': {
                'Container': 'List',
                'Optional': True,
                'Types': ['public.folder'],
            },
            'AMRequiredResources': [],
            'ActionBundlePath': '/System/Library/Automator/Run Shell Script.action',
            'ActionName': 'Run Shell Script',
            'ActionParameters': {
                'COMMAND_STRING': COMMAND_STRING,
                'CheckedForUserDefaultShell': True,
                'inputMethod': 1,
                'shell': '/bin/bash',
                'source': SOURCE,
            },
            'BundleIdentifier': 'com.apple.RunShellScript',
            'CFBundleVersion': '2.0.3',
            'CanShowSelectedItemsWhenRun': False,
            'CanShowWhenRun': False,
            'Category': ['AMCategoryUtilities'],
            'Class Name': 'RunShellScriptAction',
            'InputUUID': str(uuid.uuid4()).upper(),
            'Keywords': ['Shell', 'Script', 'Command', 'Run', 'Unix'],
            'OutputUUID': str(uuid.uuid4()).upper(),
            'ShowWhenRun': False,
            'UUID': str(uuid.uuid4()).upper(),
            'isViewVisible': True,
            'location': '309.500000:554.000000',
            'nibPath': '/System/Library/Automator/Run Shell Script.action/Contents/Resources/English.lproj/main.nib',
        },
        'isViewVisible': True,
    }],
    'connectors': {},
    'state': {
        'AMLogTabViewSelectedIndex': 0,
        'libraryState': {
            'actionsMajorSplitViewState': {
                'expandedPosition': 0.0,
                'subviewState': [
                    '0.000000, 0.000000, 381.000000, 515.000000, NO',
                    '0.000000, 516.000000, 381.000000, 239.000000, NO',
                ],
            },
            'actionsMinorSplitViewState': {
                'expandedPosition': 0.0,
                'subviewState': [
                    '0.000000, 0.000000, 163.000000, 515.000000, NO',
                    '164.000000, 0.000000, 217.000000, 515.000000, NO',
                ],
            },
            'variablesMajorSplitViewState': {
                'expandedPosition': 0.0,
                'subviewState': [
                    '0.000000, 0.000000, 350.000000, 555.000000, NO',
                    '0.000000, 556.000000, 350.000000, 148.000000, NO',
                ],
            },
            'variablesMinorSplitViewState': {
                'expandedPosition': 0.0,
                'subviewState': [
                    '0.000000, 0.000000, 163.000000, 555.000000, NO',
                    '164.000000, 0.000000, 186.000000, 555.000000, NO',
                ],
            },
        },
        'majorSplitViewState': {
            'expandedPosition': 0.0,
            'subviewState': [
                '0.000000, 0.000000, 381.000000, 800.000000, NO',
                '382.000000, 0.000000, 619.000000, 800.000000, NO',
            ],
        },
        'minorSplitViewState': {
            'expandedPosition': 0.0,
            'subviewState': [
                '0.000000, 0.000000, 619.000000, 609.000000, NO',
                '0.000000, 619.000000, 619.000000, 162.000000, NO',
            ],
        },
        'windowFrame': '{{84, 666}, {1000, 878}}',
        'workflowViewScrollPosition': '{{0, 0}, {619, 609}}',
    },
    'workflowMetaData': {
        'serviceApplicationBundleID': 'com.apple.finder',
        'serviceApplicationPath': '/System/Library/CoreServices/Finder.app',
        'serviceInputTypeIdentifier': 'com.apple.Automator.fileSystemObject',
        'serviceOutputTypeIdentifier': 'com.apple.Automator.nothing',
        'serviceProcessesInput': True,
        'workflowTypeIdentifier': 'com.apple.Automator.servicesMenu',
    },
}

with open(os.path.join(resources_dir, 'document.wflow'), 'wb') as f:
    plistlib.dump(wf, f)
PYEOF

echo "  [+] Contents/Resources/document.wflow"

# ===================== 注册服务 =====================

if [ -x /System/Library/CoreServices/pbs ]; then
    /System/Library/CoreServices/pbs -flush 2>/dev/null || true
fi

killall Finder 2>/dev/null || true

echo ""
echo "  Done! 右键 Finder 中的文件夹 → 服务 → OpenCode"
