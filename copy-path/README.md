# macOS 右键「Copy Path」服务

## 路径

`~/Library/Services/Copy Path.workflow/`

## 功能

在 Finder 中右键文件/文件夹 → **服务** → **Copy Path**，将 POSIX 路径复制到剪贴板（多文件用换行分隔）。

## 文件结构

```
Copy Path.workflow/
└── Contents/
    ├── Info.plist                # 服务注册信息
    └── Resources/
        └── document.wflow        # 工作流定义
```

> macOS 12+ 使用 `Resources/document.wflow` + `actions/action` 结构（macOS 11 未实测，架构相近）。

---

## Info.plist

`Contents/Info.plist` — 注册 Finder 服务菜单项：

```xml
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
```

### 关键点

| key | 值 | 说明 |
|-----|-----|------|
| `NSSendFileTypes` | `public.item` | 匹配所有文件/文件夹（UTI） |
| `NSRequiredContext.NSApplicationIdentifier` | `com.apple.finder` | 限定只在 Finder 中显示 |
| `NSMessage` | `runWorkflowAsService` | Automator 服务固定值 |

---

## document.wflow

`Contents/Resources/document.wflow` — 工作流定义：

```python
import plistlib, uuid

wf = {
    'AMApplicationBuild': '307',
    'AMApplicationVersion': '2.2',
    'AMDocumentVersion': '2',
    'actions': [{
        'action': {
            'AMAccepts': {
                'Container': 'List',
                'Optional': True,
                'Types': ['public.item']
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
                'Types': ['public.item']
            },
            'AMRequiredResources': [],
            'ActionBundlePath': '/System/Library/Automator/Run Shell Script.action',
            'ActionName': 'Run Shell Script',
            'ActionParameters': {
                'COMMAND_STRING':
                    'printf "%s\\n" "$@" | /usr/bin/pbcopy',
                'CheckedForUserDefaultShell': True,
                'inputMethod': 1,
                'shell': '/bin/bash',
                'source':
                    '#!/bin/bash\n'
                    'export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8\n'
                    'printf "%s\\n" "$@" | /usr/bin/pbcopy',
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
            'nibPath':
                '/System/Library/Automator/Run Shell Script.action/'
                'Contents/Resources/English.lproj/main.nib',
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

with open(
    '/Users/zuoyong.tang/Library/Services/Copy Path.workflow/'
    'Contents/Resources/document.wflow', 'wb'
) as f:
    plistlib.dump(wf, f)
```

### 关键点

| 参数 | 值 | 说明 |
|------|-----|------|
| `inputMethod` | `1` | 接收为参数（`$@`），而非 stdin |
| `shell` | `/bin/bash` | 使用 bash（而非 sh） |
| `COMMAND_STRING` | `printf "%s\n" "$@" \| /usr/bin/pbcopy` | 单行命令字符串 |
| `source` | `#!/bin/bash` + `export LANG=...` + `printf ...` | shell 脚本全文，含 shebang 和环境变量 |
| `serviceInputTypeIdentifier` | `com.apple.Automator.fileSystemObject` | 接收文件系统对象 |
| `serviceProcessesInput` | `True` | 处理输入 |
| `AMAccepts.Types` | `["public.item"]` | 接受所有文件/文件夹 |

---

## 注册服务

创建文件后，刷新服务缓存：

```bash
/System/Library/CoreServices/pbs -flush
killall Finder
```

---

## CLI 调试

用 `automator -i -` 从命令行传递输入测试：

```bash
printf "/tmp/file1\n/tmp/file2" | automator -i - ~/Library/Services/Copy\ Path.workflow
pbpaste
# 预期输出：/tmp/file1
#           /tmp/file2
```

> `automator` 的 `-i -` 选项从 stdin 读取，每行视为一个输入项。

---

## 踩坑记录

| 问题 | 原因 | 修复 |
|------|------|------|
| 右键看不到「服务」 | `NSSendFileTypes` 用 `NSFilenamesPboardType`（旧格式） | 改为 `public.item`（UTI） |
| 右键能看到但点后无反应 | `Info.plist` 缺少 `NSRequiredContext` / `NSSendFileTypes` 放在顶层而非 `NSServices` 内 | 补全 `NSRequiredContext` 并修正结构 |
| 含中文路径不工作 | 缺少 UTF-8 环境变量 | 脚本中设置 `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` |
| 右键可见但点了没反应（macOS 12） | `document.wflow` 误用旧格式（`AMWorkflowActions` + `Contents/`），实际需要新格式（`actions/action` + `Resources/`） | 改用新格式，置于 `Resources/` 下 |
