# Power-in-Bar

macOS 状态栏系统监控工具 + CLI 命令行工具。

## 功能

- **状态栏显示**：菜单栏实时显示功耗、CPU、内存；点击下拉查看全部系统指标
- **CLI 工具**：终端执行 `power` 输出电源、CPU、内存、磁盘、网络、温度、风扇、GPU 状态

## 安装

```bash
sh install.sh
```

或一键远程安装：

```bash
zsh <(curl -L https://raw.githubusercontent.com/xiaodi0003/mac-tools/main/power-in-bar/install.sh)
```

会自动：
1. 安装 `power` CLI 到 `/usr/local/bin`
2. 安装 `powermetrics-reader` 传感器辅助脚本到 `/usr/local/bin`
3. 编译并安装 `PowerMonitor.app` 到 `/Applications`
4. 启动 PowerMonitor 状态栏显示

### 启用传感器数据（温度 / 风扇 / GPU）

```bash
sudo power setup-sudo
```

此命令添加 sudoers 规则，使 `powermetrics-reader` 免密读取传感器数据。不执行则温度/风扇/GPU 显示为 N/A。

## 卸载

```bash
sh uninstall.sh
```

或手动删除：

```bash
rm -rf /Applications/PowerMonitor.app /usr/local/bin/power /usr/local/bin/powermetrics-reader /etc/sudoers.d/powermetrics
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

======= CPU =======
Usage:   12.5% (user 8.1%, sys 4.4%)
Idle:    87.5%

======= Memory =======
Used:    12.5 GB / 16.0 GB (78%)

======= Disk =======
Used:    345.0 GB / 512.0 GB (67%)

======= Thermal =======
CPU Temp:  42.5°C
Fan Speed: 2800 RPM
GPU Temp:  41.0°C
GPU Util:  45%

======= Network (cumulative) =======
Download: 125.0 GB
Upload:   25.0 GB
============================
```

## 数据来源

- `ioreg -r -c AppleSmartBattery` — 读取电池电流、电压、AC 输入功率
- `system_profiler SPPowerDataType` — 读取适配器额定功率
- `top` / `vm_stat` / `df` / `netstat` — CPU、内存、磁盘、网络
- `powermetrics` — 温度、风扇转速、GPU 利用率（需 sudo）
