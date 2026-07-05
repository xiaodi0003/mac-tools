#!/bin/bash
# power.sh - 获取电源输入功率、电池功率和系统消耗功率 (macOS)
# 通过 ioreg 读取 SMC 电源数据

set -euo pipefail

raw=$(ioreg -r -c AppleSmartBattery 2>/dev/null) || true

# ----- PowerTelemetryData (AC 输入功率) -----
system_power_in=$(echo "$raw" | tr ',' '\n' | grep '"SystemPowerIn"=' | cut -d= -f2) || true

# ----- LegacyBatteryInfo (电池电流、电压) -----
batt_amp=$(echo "$raw" | grep -o '"Amperage"=[-0-9]*' | cut -d= -f2) || true
batt_mv=$(echo "$raw" | grep -o '"Voltage"=[0-9]*' | head -1 | cut -d= -f2) || true

# 处理负值 (64-bit 无符号存储)
to_signed() {
    local val=$1
    if [ "$val" -gt 9223372036854775807 ] 2>/dev/null; then
        echo $((val - 18446744073709551616))
    else
        echo "$val"
    fi
}

system_power_in=$(to_signed "${system_power_in:-0}")
batt_amp=$(to_signed "${batt_amp:-0}")

# 计算 (mW -> W)
calc() { awk "BEGIN{printf \"%.2f\", $1}"; }

ac_input_w=$(calc "$system_power_in / 1000")

# 电池功率 = Amperage(mA) × Voltage(mV) / 10^6 → W
battery_w=$(calc "($batt_amp * ${batt_mv:-0}) / 1000000")

# 系统消耗 = AC 输入 - 电池功率 (电池充电时 Amperage > 0)
consumption_w=$(calc "($system_power_in - ($batt_amp * ${batt_mv:-0}) / 1000) / 1000")

# AC 适配器额定功率
charger_wattage=$(system_profiler SPPowerDataType 2>/dev/null | grep "Wattage (W)" | awk '{print $3}') || true

# 电池充放电状态
batt_status=$(pmset -g batt 2>/dev/null | grep -oE '(not charging|charging|discharging)' | head -1) || true

# 电池方向标识
if [ "$batt_amp" -gt 0 ] 2>/dev/null; then
    dir="→ charging"
elif [ "$batt_amp" -lt 0 ] 2>/dev/null; then
    dir="→ discharging"
else
    dir="idle"
fi

echo "======= Power Status ======="
echo "Adapter Rating:    ${charger_wattage:-?} W"
echo "AC Input:          ${ac_input_w} W"
echo "Battery:           ${battery_w} W ${dir}"
echo "System Consumption: ${consumption_w} W"
echo "============================"
