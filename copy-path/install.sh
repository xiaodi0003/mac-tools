#!/bin/bash
# install-copy-path-service.sh
# Install Finder 右键「Copy Path」服务
# 兼容 macOS 11 ~ 26（11 未实测，但架构与 12 相近）

set -euo pipefail

SERVICE_DIR="$HOME/Library/Services/Copy Path.workflow"
CONTENTS_DIR="$SERVICE_DIR/Contents"

# ===================== 清理旧文件 =====================

# 清除旧格式遗留文件（之前版本放在 Contents/ 下而非 Resources/）
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
    <string>com.user.services.copyPath</string>
    <key>CFBundleName</key>
    <string>Copy Path</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Copy Path</string>
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
                <string>public.item</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
INFO

echo "  [+] Contents/Info.plist"

# ===================== document.wflow =====================

# Shell 脚本内容
read -r -d '' SOURCE <<'SCRIPT' || true
#!/bin/bash
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
printf "%s\n" "$@" | /usr/bin/pbcopy
SCRIPT

# 转义过的单行版命令字符串
COMMAND_STRING='printf "%s\n" "$@" | /usr/bin/pbcopy'

cat > "$CONTENTS_DIR/Resources/document.wflow" <<WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>307</string>
    <key>AMApplicationVersion</key>
    <string>2.2</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>public.item</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>
                    <key>CheckedForUserDefaultShell</key>
                    <dict/>
                    <key>inputMethod</key>
                    <dict/>
                    <key>shell</key>
                    <dict/>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>public.item</string>
                    </array>
                </dict>
                <key>AMRequiredResources</key>
                <array/>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>$(printf '%s' "$COMMAND_STRING" | sed 's/"/\&quot;/g')</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string>$(printf '%s' "$SOURCE" | sed 's/&/\&amp;/g; s/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')</string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <false/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>$(uuidgen | tr a-z A-Z)</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                    <string>Command</string>
                    <string>Run</string>
                    <string>Unix</string>
                </array>
                <key>OutputUUID</key>
                <string>$(uuidgen | tr a-z A-Z)</string>
                <key>ShowWhenRun</key>
                <false/>
                <key>UUID</key>
                <string>$(uuidgen | tr a-z A-Z)</string>
                <key>isViewVisible</key>
                <true/>
                <key>location</key>
                <string>309.500000:554.000000</string>
                <key>nibPath</key>
                <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/English.lproj/main.nib</string>
            </dict>
            <key>isViewVisible</key>
            <true/>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>state</key>
    <dict>
        <key>AMLogTabViewSelectedIndex</key>
        <integer>0</integer>
        <key>libraryState</key>
        <dict>
            <key>actionsMajorSplitViewState</key>
            <dict>
                <key>expandedPosition</key>
                <real>0.0</real>
                <key>subviewState</key>
                <array>
                    <string>0.000000, 0.000000, 381.000000, 515.000000, NO</string>
                    <string>0.000000, 516.000000, 381.000000, 239.000000, NO</string>
                </array>
            </dict>
            <key>actionsMinorSplitViewState</key>
            <dict>
                <key>expandedPosition</key>
                <real>0.0</real>
                <key>subviewState</key>
                <array>
                    <string>0.000000, 0.000000, 163.000000, 515.000000, NO</string>
                    <string>164.000000, 0.000000, 217.000000, 515.000000, NO</string>
                </array>
            </dict>
            <key>variablesMajorSplitViewState</key>
            <dict>
                <key>expandedPosition</key>
                <real>0.0</real>
                <key>subviewState</key>
                <array>
                    <string>0.000000, 0.000000, 350.000000, 555.000000, NO</string>
                    <string>0.000000, 556.000000, 350.000000, 148.000000, NO</string>
                </array>
            </dict>
            <key>variablesMinorSplitViewState</key>
            <dict>
                <key>expandedPosition</key>
                <real>0.0</real>
                <key>subviewState</key>
                <array>
                    <string>0.000000, 0.000000, 163.000000, 555.000000, NO</string>
                    <string>164.000000, 0.000000, 186.000000, 555.000000, NO</string>
                </array>
            </dict>
        </dict>
        <key>majorSplitViewState</key>
        <dict>
            <key>expandedPosition</key>
            <real>0.0</real>
            <key>subviewState</key>
            <array>
                <string>0.000000, 0.000000, 381.000000, 800.000000, NO</string>
                <string>382.000000, 0.000000, 619.000000, 800.000000, NO</string>
            </array>
        </dict>
        <key>minorSplitViewState</key>
        <dict>
            <key>expandedPosition</key>
            <real>0.0</real>
            <key>subviewState</key>
            <array>
                <string>0.000000, 0.000000, 619.000000, 609.000000, NO</string>
                <string>0.000000, 619.000000, 619.000000, 162.000000, NO</string>
            </array>
        </dict>
        <key>windowFrame</key>
        <string>{{84, 666}, {1000, 878}}</string>
        <key>workflowViewScrollPosition</key>
        <string>{{0, 0}, {619, 609}}</string>
    </dict>
    <key>workflowMetaData</key>
    <dict>
        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>
        <key>serviceApplicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <true/>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
WFLOW

echo "  [+] Contents/Resources/document.wflow"

# ===================== 注册服务 =====================

# 刷新服务注册缓存
if [ -x /System/Library/CoreServices/pbs ]; then
    /System/Library/CoreServices/pbs -flush 2>/dev/null || true
fi

# 重启 Finder 使其重新加载服务列表
killall Finder 2>/dev/null || true

echo ""
echo "  Done! 右键 Finder 中的文件/文件夹 → 服务 → Copy Path"
echo ""
echo "  Test:"
echo '    printf "/tmp/foo\n/tmp/bar" | automator -i - ~/Library/Services/Copy\ Path.workflow'
echo "    pbpaste"
