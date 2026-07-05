# Power-in-Bar

macOS 状态栏电源功率监控工具 + CLI 命令行工具。

## 功能

- **状态栏显示**：菜单栏实时显示系统功耗（如 `12.3W ⚡`），点击展开详情（适配器功率 / AC 输入 / 电池功率 / 系统功耗）
- **CLI 工具**：终端执行 `power` 命令，输出当前电源状态

## 安装

```bash
sh install.sh
```

会自动：
1. 安装 `power` CLI 到 `/usr/local/bin`
2. 编译并安装 `PowerMonitor.app` 到 `/Applications`
3. 启动 PowerMonitor 状态栏显示

## 卸载

```bash
sh uninstall.sh
```

或手动删除：

```bash
rm -rf /Applications/PowerMonitor.app /usr/local/bin/power
```

## 最低系统版本

**macOS 13 (Ventura)** 及以上。

`SystemPowerIn` 数据来自 IOKit `PowerTelemetryData` 对象，该对象仅 macOS 13+ 支持。更早版本无法获取 AC 输入功率数据。

## CLI 使用

```bash
$ power
======= Power Status =======
Adapter Rating:    96 W
AC Input:          18.50 W
Battery:           8.24 W → charging
System Consumption: 10.26 W
============================
```

## 数据来源

- `ioreg -r -c AppleSmartBattery` — 读取电池电流、电压、AC 输入功率
- `system_profiler SPPowerDataType` — 读取适配器额定功率
- `pmset -g batt` — 获取电池充放电状态
