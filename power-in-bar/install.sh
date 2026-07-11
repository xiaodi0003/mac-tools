#!/bin/bash
# install.sh - 安装 PowerMonitor.app 状态栏系统监控 + power CLI 工具
set -euo pipefail

APP_NAME="PowerMonitor"
APP_DIR="/Applications/${APP_NAME}.app"
SWIFT_SRC="/tmp/${APP_NAME}-build"

echo "==> Installing power CLI to /usr/local/bin ..."
mkdir -p /usr/local/bin
cat > /usr/local/bin/power << 'POWER_SCRIPT'
#!/bin/bash
# power - 系统状态监控 CLI (macOS)
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
fmt2() { awk "BEGIN{printf \"%s\", $1}"; }

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
    # We can't compute rate from single snapshot, show cumulative
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
POWER_SCRIPT
chmod +x /usr/local/bin/power
echo "    Run 'power' anytime to check power status."

echo "==> Building ${APP_NAME}.app (SwiftUI MenuBarExtra) ..."
rm -rf "$SWIFT_SRC"
mkdir -p "$SWIFT_SRC/Sources"

# 嵌入式 Swift 源码
cat > "$SWIFT_SRC/Sources/main.swift" << 'SWIFT_EOF'
import SwiftUI
import AppKit
import Foundation
import Darwin

// MARK: - Process Helper (only for power + thermal)
func runCmd(_ path: String, args: [String]) -> String? {
    let p = Process(); p.launchPath = path; p.arguments = args
    let o = Pipe(); p.standardOutput = o; p.standardError = o
    try? p.run(); p.waitUntilExit()
    let data = o.fileHandleForReading.readDataToEndOfFile()
    return data.isEmpty ? nil : String(data: data, encoding: .utf8)
}

// MARK: - SystemMonitor
@MainActor
class SystemMonitor: ObservableObject {
    // Power
    @Published var acPower: Double = 0
    @Published var batPower: Double = 0
    @Published var sysPower: Double = 0
    @Published var batDirection: String = ""
    @Published var chargerRating: String = "?"

    // CPU
    @Published var cpuUser: Double = 0
    @Published var cpuSys: Double = 0
    @Published var cpuIdle: Double = 0

    // Memory
    @Published var memUsedGB: Double = 0
    @Published var memTotalGB: Double = 0

    // Disk
    @Published var diskUsedGB: Double = 0
    @Published var diskTotalGB: Double = 0

    // Thermal
    @Published var cpuTemp: Double?
    @Published var gpuTemp: Double?
    @Published var fanSpeed: Int?

    // GPU
    @Published var gpuUtil: Double?

    // Network (bytes/sec)
    @Published var netInSpeed: Double = 0
    @Published var netOutSpeed: Double = 0

    private var prevNetIBytes: UInt64 = 0
    private var prevNetOBytes: UInt64 = 0
    private var prevNetTime = Date()
    // CPU delta tracking
    private var prevCPUTicks: (user: UInt64, sys: UInt64, idle: UInt64) = (0, 0, 0)
    private var cpuFirstRead = true
    // Charger rating cache
    private var chargerCached = false
    // Timer
    private var timer: Timer?

    init() {
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    var cpuPercent: Double { cpuUser + cpuSys }
    var memPercent: Double { memTotalGB > 0 ? memUsedGB / memTotalGB * 100 : 0 }
    var diskPercent: Double { diskTotalGB > 0 ? diskUsedGB / diskTotalGB * 100 : 0 }

    func start() {
        readMemoryTotal()
        readDisk()
        readAll()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.readAll() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func readAll() {
        readPower()
        readCPU()
        readMemory()
        readDisk()
        readThermal()
        readNetwork()
    }

    // MARK: - Power (ioreg, fast < 50ms)
    func readPower() {
        guard let raw = runCmd("/usr/sbin/ioreg", args: ["-r", "-c", "AppleSmartBattery"]),
              let ac = Self.extractValue(from: raw, key: "SystemPowerIn"),
              let ampRaw = Self.extractUInt64(from: raw, key: "Amperage"),
              let mv = Self.extractVoltage(from: raw) else { return }

        let amp = Self.toSigned(ampRaw)
        let acD = Double(ac); let ampD = Double(amp); let mvD = Double(mv)

        acPower = acD / 1000.0
        batPower = abs(ampD * mvD / 1_000_000.0)
        sysPower = (acD - ampD * mvD / 1000.0) / 1000.0

        if amp > 0 { batDirection = "⚡" }
        else if amp < 0 { batDirection = "🔋" }
        else { batDirection = "" }

        if !chargerCached, let profiler = runCmd("/usr/sbin/system_profiler", args: ["SPPowerDataType"]) {
            for line in profiler.components(separatedBy: .newlines) {
                if line.contains("Wattage (W)") {
                    chargerRating = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "?"
                    chargerCached = true
                    break
                }
            }
        }
    }

    static func toSigned(_ val: UInt64) -> Int {
        if val > UInt64(Int64.max) { return Int(val - UInt64(Int64.max) - 1) - Int(Int64.max) - 1 }
        return Int(val)
    }

    static func extractValue(from text: String, key: String) -> Int? {
        guard let r = text.range(of: "\"\(key)\"=") else { return nil }
        var s = ""
        for ch in text[r.upperBound...] { if ch == "-" || ch.isNumber { s.append(ch) } else { break } }
        return Int(s)
    }

    static func extractUInt64(from text: String, key: String) -> UInt64? {
        guard let r = text.range(of: "\"\(key)\"=") else { return nil }
        var s = ""
        for ch in text[r.upperBound...] { if ch.isNumber { s.append(ch) } else { break } }
        return UInt64(s)
    }

    static func extractVoltage(from text: String) -> Int? {
        guard let r = text.range(of: "\"Voltage\"=") else { return nil }
        var s = ""
        for ch in text[r.upperBound...] { if ch.isNumber { s.append(ch) } else if ch == "," || ch == "}" { break } }
        return Int(s)
    }

    // MARK: - CPU (Darwin host_statistics, instant)
    func readCPU() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let ret = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard ret == KERN_SUCCESS else { return }

        let user = UInt64(cpuInfo.cpu_ticks.0)
        let sys  = UInt64(cpuInfo.cpu_ticks.1)
        let idle = UInt64(cpuInfo.cpu_ticks.2)

        if cpuFirstRead {
            cpuFirstRead = false
            prevCPUTicks = (user, sys, idle)
            return
        }

        let du = user - prevCPUTicks.user
        let ds = sys  - prevCPUTicks.sys
        let di = idle - prevCPUTicks.idle
        let dt = du + ds + di

        if dt > 0 {
            cpuUser = Double(du) / Double(dt) * 100.0
            cpuSys  = Double(ds) / Double(dt) * 100.0
            cpuIdle = Double(di) / Double(dt) * 100.0
        }
        prevCPUTicks = (user, sys, idle)
    }

    // MARK: - Memory (Darwin host_statistics64 + ProcessInfo, instant)
    func readMemoryTotal() {
        memTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }

    func readMemory() {
        var vmInfo = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let ret = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard ret == KERN_SUCCESS else { return }

        let pageSize = UInt64(getpagesize())
        let used = UInt64(vmInfo.active_count + vmInfo.wire_count + vmInfo.compressor_page_count) * pageSize
        memUsedGB = Double(used) / 1_073_741_824.0
    }

    // MARK: - Disk (Darwin statfs, instant)
    func readDisk() {
        let path = FileManager.default.fileExists(atPath: "/System/Volumes/Data") ? "/System/Volumes/Data" : "/"
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return }

        let total = UInt64(fs.f_blocks) * UInt64(fs.f_bsize)
        let avail = UInt64(fs.f_bavail) * UInt64(fs.f_bsize)
        let used  = total - avail

        diskTotalGB = Double(total) / 1_073_741_824.0
        diskUsedGB  = Double(used)  / 1_073_741_824.0
    }

    // MARK: - Thermal & GPU (powermetrics-reader)
    func readThermal() {
        let helper = "/usr/local/bin/powermetrics-reader"
        guard FileManager.default.isExecutableFile(atPath: helper) else { return }
        Task { @MainActor [weak self] in
            let result = await Task.detached { () -> (cpu: Double?, gpu: Double?, fan: Int?, util: Double?)? in
                let p = Process()
                p.launchPath = "/usr/bin/sudo"
                p.arguments = [helper]
                let o = Pipe()
                p.standardOutput = o
                p.standardError = Pipe()
                try? p.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { if p.isRunning { p.terminate() } }
                p.waitUntilExit()
                guard let out = String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
                      !out.isEmpty else { return nil }
                var cpu: Double?; var gpu: Double?; var fan: Int?; var util: Double?
                for line in out.components(separatedBy: .newlines) {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.contains("CPU die temperature") {
                        cpu = Double(t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? "")
                    } else if t.contains("GPU die temperature") {
                        gpu = Double(t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? "")
                    } else if t.hasPrefix("Fan:") {
                        let val = t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
                        fan = Int(Double(val) ?? 0)
                    } else if t.contains("GPU Busy") {
                        util = Double(t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).dropLast() ?? "")
                    }
                }
                return (cpu, gpu, fan, util)
            }.value
            guard let r = result else { return }
            if let t = r.cpu { self?.cpuTemp = t }
            if let t = r.gpu { self?.gpuTemp = t }
            if let f = r.fan { self?.fanSpeed = f }
            if let u = r.util { self?.gpuUtil = u }
        }
    }

    // MARK: - Network (Darwin getifaddrs, instant)
    func readNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var iBytes: UInt64 = 0
        var oBytes: UInt64 = 0
        var ptr = first
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            let sa_family = ptr.pointee.ifa_addr?.pointee.sa_family ?? 0
            if sa_family == AF_LINK, name.hasPrefix("en"), let dataPtr = ptr.pointee.ifa_data {
                let netData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                iBytes = UInt64(netData.ifi_ibytes)
                oBytes = UInt64(netData.ifi_obytes)
                break
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        let now = Date()
        if prevNetIBytes > 0 {
            let elapsed = now.timeIntervalSince(prevNetTime)
            if elapsed > 0 {
                netInSpeed = Double(iBytes - prevNetIBytes) / elapsed
                netOutSpeed = Double(oBytes - prevNetOBytes) / elapsed
            }
        }
        prevNetIBytes = iBytes; prevNetOBytes = oBytes; prevNetTime = now
    }
}

// MARK: - Views
struct MenuBarLabel: View {
    @ObservedObject var mon: SystemMonitor
    var body: some View {
        let arrow = mon.batDirection == "⚡" ? "↓" :
                    mon.batDirection == "🔋" ? "↑" : "–"
        HStack(spacing: 4) {
            Text("\(arrow)\(mon.sysPower, specifier: "%.1f")W")
                .font(.system(size: 10, weight: .medium))
            Text("CPU\(Int(mon.cpuPercent))%")
                .font(.system(size: 9, weight: .light))
            Text("MEM\(mon.memUsedGB, specifier: "%.0f")G")
                .font(.system(size: 9, weight: .light))
        }
    }
}

struct MenuDropdown: View {
    @ObservedObject var mon: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⚡ Power:           \(mon.sysPower, specifier: "%.1f") W")
            Text("  Adapter:          \(mon.chargerRating) W")
            Text("  AC Input:         \(mon.acPower, specifier: "%.1f") W")
            Text("  Battery:          \(mon.batPower, specifier: "%.1f") W \(mon.batDirection)")
            Divider()
            Text("🖥 CPU:             \(mon.cpuPercent, specifier: "%.1f")%")
            Text("  User/Sys:         \(mon.cpuUser, specifier: "%.1f")/\(mon.cpuSys, specifier: "%.1f")%")
            Divider()
            Text("🐏 Memory:          \(mon.memUsedGB, specifier: "%.1f")/\(mon.memTotalGB, specifier: "%.1f") GB (\(mon.memPercent, specifier: "%.0f")%)")
            Divider()
            Text("💾 Disk:            \(mon.diskUsedGB, specifier: "%.1f")/\(mon.diskTotalGB, specifier: "%.1f") GB (\(mon.diskPercent, specifier: "%.0f")%)")
            Divider()
            if let t = mon.cpuTemp {
                Text("🌡 CPU:             \(t, specifier: "%.0f")°C")
                if let f = mon.fanSpeed { Text("  Fan:              \(f) RPM") }
            } else {
                Text("🌡 N/A")
            }
            Divider()
            if let t = mon.gpuTemp {
                Text("🎮 GPU:             \(t, specifier: "%.0f")°C")
                if let u = mon.gpuUtil { Text("  Util:             \(u, specifier: "%.0f")%") }
            } else {
                Text("🎮 GPU:             N/A")
            }
            Divider()
            Text("🌐 ↓:               \(formatBytes(mon.netInSpeed))/s")
            Text("🌐 ↑:               \(formatBytes(mon.netOutSpeed))/s")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(.horizontal, 4)
        .frame(width: 210)
    }

    func formatBytes(_ bps: Double) -> String {
        if bps >= 1_073_741_824 { return String(format: "%.1f GB", bps / 1_073_741_824.0) }
        if bps >= 1_048_576 { return String(format: "%.1f MB", bps / 1_048_576.0) }
        if bps >= 1024 { return String(format: "%.0f KB", bps / 1024.0) }
        return String(format: "%.0f B", bps)
    }
}

// MARK: - App
@main
struct PowerMonitorApp: App {
    @StateObject private var mon = SystemMonitor()
    var body: some Scene {
        MenuBarExtra {
            MenuDropdown(mon: mon)
        } label: {
            MenuBarLabel(mon: mon)
        }
        .menuBarExtraStyle(.menu)
    }
}
SWIFT_EOF

echo -n "    Compiling ... "
cd "$SWIFT_SRC"
swiftc -o "$APP_NAME" -parse-as-library -framework SwiftUI -framework AppKit Sources/main.swift 2>&1
echo "done."

echo -n "    Creating .app bundle ... "
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$SWIFT_SRC/$APP_NAME" "$APP_DIR/Contents/MacOS/"

cat > "$APP_DIR/Contents/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST_EOF

codesign -s - "$APP_DIR" 2>/dev/null
echo "done."

echo "==> Installing powermetrics-reader helper for sensor data ..."
cat > /usr/local/bin/powermetrics-reader << 'PM_HELPER'
#!/bin/bash
# powermetrics-reader - 读取温度/风扇转速/GPU 数据 (需 sudo)
# 配合 sudoers 规则可免密运行
/usr/bin/powermetrics --samplers smc,gpu_power -n 1 -i 1 2>/dev/null \
  | grep -v "^$" | grep -v "^\*"
PM_HELPER
chmod +x /usr/local/bin/powermetrics-reader
echo "    Helper installed to /usr/local/bin/powermetrics-reader"

echo "==> Setting up passwordless sudo for sensor data ..."
sudo bash -c 'echo "'$(whoami)' ALL=(root) NOPASSWD: /usr/local/bin/powermetrics-reader" > /etc/sudoers.d/powermetrics && chmod 0440 /etc/sudoers.d/powermetrics' 2>/dev/null \
  && echo "    Done. Temperature/fan/GPU data enabled." \
  || echo "    Skipped (run 'sudo power setup-sudo' manually to enable)."

echo "==> Launching ${APP_NAME}.app ..."
killall "$APP_NAME" 2>/dev/null || true
open "$APP_DIR"

echo "==> Adding to Login Items ..."
osascript -e "
tell application \"System Events\"
    set existing to every login item whose path is \"$APP_DIR\"
    if existing is {} then
        make login item at end with properties {path:\"$APP_DIR\", hidden:false}
    end if
end tell
" 2>/dev/null && echo "    Done." || echo "    (skipped)"

rm -rf "$SWIFT_SRC"
echo ""
echo "✅ Installed! PowerMonitor is now in your menu bar."
echo "   - Menu bar:  CPU% MEM ↑/↓WW"
echo "   - Click for: Power / CPU / Memory / Disk / Thermal / GPU / Network"
echo "   - CLI:       power"
echo "   - Sensors:   sudo power setup-sudo  (enables temp/fan/GPU)"
echo ""
echo "To remove:"
echo "   rm -rf /Applications/PowerMonitor.app /usr/local/bin/power /usr/local/bin/powermetrics-reader"
