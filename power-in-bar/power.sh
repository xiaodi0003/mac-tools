#!/bin/bash
# power.sh - 系统状态监控 (macOS)
set -euo pipefail

# ---- Subcommands ----
if [ "${1:-}" = "setup-sudo" ]; then
    SUDOERS_FILE="/etc/sudoers.d/powermetrics"
    WHOAMI=$(whoami)
    HELPER="/usr/local/bin/powermetrics-reader"
    if [ ! -f "$HELPER" ]; then
        echo "Error: $HELPER not found. Re-run install.sh first." >&2
        exit 1
    fi
    echo "Adding sudoers rule for $WHOAMI to run powermetrics-reader without password..."
    echo "$WHOAMI ALL=(root) NOPASSWD: $HELPER" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
    echo "Done! Temperature, fan, and GPU data will now be available."
    exit 0
fi

# ---- Power ----
raw=$(ioreg -r -c AppleSmartBattery 2>/dev/null) || true
system_power_in=$(echo "$raw" | tr ',' '\n' | grep '"SystemPowerIn"=' | cut -d= -f2) || true
batt_amp=$(echo "$raw" | grep -o '"Amperage"=[-0-9]*' | cut -d= -f2) || true
batt_mv=$(echo "$raw" | grep -o '"Voltage"=[0-9]*' | head -1 | cut -d= -f2) || true

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

calc() { awk "BEGIN{printf \"%.2f\", $1}"; }
fmt() { awk "BEGIN{printf \"%.1f\", $1}"; }

ac_input_w=$(calc "$system_power_in / 1000")
battery_w=$(calc "($batt_amp * ${batt_mv:-0}) / 1000000")
consumption_w=$(calc "($system_power_in - ($batt_amp * ${batt_mv:-0}) / 1000) / 1000")

charger_wattage=$(system_profiler SPPowerDataType 2>/dev/null | grep "Wattage (W)" | awk '{print $3}') || true

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

# ---- CPU ----
cpu_line=$(top -l 1 -n 0 -s 0 2>/dev/null | grep "CPU usage") || true
if [ -n "$cpu_line" ]; then
  cpu_user=$(echo "$cpu_line" | awk '{print $3}' | tr -d '%')
  cpu_sys=$(echo "$cpu_line" | awk '{print $5}' | tr -d '%')
  cpu_idle=$(echo "$cpu_line" | awk '{print $7}' | tr -d '%')
else
  cpu_user=0; cpu_sys=0; cpu_idle=0
fi
echo ""
echo "======= CPU ======="
echo "Usage:   $(fmt "$cpu_user + $cpu_sys")% (user ${cpu_user}%, sys ${cpu_sys}%)"
echo "Idle:    ${cpu_idle}%"

# ---- Memory ----
mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
mem_total_gb=$(calc "$mem_total / 1073741824")
vm_stat_out=$(vm_stat 2>/dev/null) || true
page_size=$(echo "$vm_stat_out" | grep "page size of" | grep -oE '[0-9]+' | tail -1)
page_size=${page_size:-16384}
pages_active=$(echo "$vm_stat_out" | grep "Pages active:" | grep -oE '[0-9]+')
pages_wired=$(echo "$vm_stat_out" | grep "Pages wired" | grep -oE '[0-9]+')
pages_compressed=$(echo "$vm_stat_out" | grep "Pages occupied by compressor" | grep -oE '[0-9]+')
mem_used_gb=$(calc "(${pages_active:-0} + ${pages_wired:-0} + ${pages_compressed:-0}) * $page_size / 1073741824")
mem_percent=$(calc "($mem_used_gb / $mem_total_gb) * 100" | awk '{printf "%.0f", $1}')
echo ""
echo "======= Memory ======="
echo "Used:    $(fmt "$mem_used_gb") GB / $(fmt "$mem_total_gb") GB (${mem_percent}%)"

# ---- Disk ----
disk_target="/System/Volumes/Data"
[ ! -d "$disk_target" ] && disk_target="/"
disk_line=$(df "$disk_target" 2>/dev/null | tail -1) || true
if [ -n "$disk_line" ]; then
  disk_blocks=$(echo "$disk_line" | awk '{print $2}')
  disk_used=$(echo "$disk_line" | awk '{print $3}')
  disk_total_gb=$(calc "$disk_blocks * 512 / 1073741824")
  disk_used_gb=$(calc "$disk_used * 512 / 1073741824")
  disk_percent=$(calc "($disk_used_gb / $disk_total_gb) * 100" | awk '{printf "%.0f", $1}')
fi
echo ""
echo "======= Disk ======="
echo "Used:    $(fmt "${disk_used_gb:-0}") GB / $(fmt "${disk_total_gb:-0}") GB (${disk_percent:-0}%)"

# ---- Temperature / Fan / GPU (via powermetrics helper) ----
helper="/usr/local/bin/powermetrics-reader"
if [ -x "$helper" ]; then
  pm_out=$("$helper" 2>/dev/null) || true
  if [ -n "$pm_out" ]; then
    temp=$(echo "$pm_out" | grep -i "CPU die temperature" | awk -F': ' '{print $2}' | awk '{print $1}')
    gpu_temp=$(echo "$pm_out" | grep -i "GPU die temperature" | awk -F': ' '{print $2}' | awk '{print $1}')
    fan=$(echo "$pm_out" | grep -i "^Fan:" | awk '{print $2}')
    gpu_util=$(echo "$pm_out" | grep -i "GPU utilization" | awk -F': ' '{print $2}' | awk '{print $1}')
    echo ""
    echo "======= Thermal ======="
    [ -n "$temp" ] && echo "CPU Temp:  ${temp}°C" || true
    [ -n "$fan" ]  && echo "Fan Speed: ${fan} RPM" || true
    [ -n "$gpu_temp" ] && echo "GPU Temp:  ${gpu_temp}°C" || true
    [ -n "$gpu_util" ] && echo "GPU Util:  ${gpu_util}%" || true
  fi
fi

# ---- Network ----
iface=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}') || true
if [ -n "$iface" ]; then
  net_line=$(netstat -ib | awk -v iface="$iface" '$1 == iface && $3 ~ /Link/ {print $7, $10}')
  if [ -n "$net_line" ]; then
    ibytes=$(echo "$net_line" | awk '{print $1}')
    obytes=$(echo "$net_line" | awk '{print $2}')
    net_in_gb=$(calc "$ibytes / 1073741824")
    net_out_gb=$(calc "$obytes / 1073741824")
    echo ""
    echo "======= Network (cumulative) ======="
    echo "Download: $(fmt "$net_in_gb") GB"
    echo "Upload:   $(fmt "$net_out_gb") GB"
  fi
fi

echo ""
echo "============================"
