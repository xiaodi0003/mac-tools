#!/bin/bash
# install.sh - 安装 PowerMonitor.app 状态栏电源监控 + power.sh CLI 工具
set -euo pipefail

APP_NAME="PowerMonitor"
APP_DIR="/Applications/${APP_NAME}.app"
SWIFT_SRC="/tmp/${APP_NAME}-build"

echo "==> Installing power CLI to /usr/local/bin ..."
cat > /usr/local/bin/power << 'POWER_SCRIPT'
#!/bin/bash
# power - 获取电源输入功率、电池功率和系统消耗功率 (macOS)
set -euo pipefail

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

ac_input_w=$(calc "$system_power_in / 1000")
battery_w=$(calc "($batt_amp * ${batt_mv:-0}) / 1000000")
consumption_w=$(calc "($system_power_in - ($batt_amp * ${batt_mv:-0}) / 1000) / 1000")

charger_wattage=$(system_profiler SPPowerDataType 2>/dev/null | grep "Wattage (W)" | awk '{print $3}') || true
batt_status=$(pmset -g batt 2>/dev/null | grep -oE '(not charging|charging|discharging)' | head -1) || true

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

@MainActor
class PowerMonitor: ObservableObject {
    @Published var acPower: Double = 0
    @Published var batPower: Double = 0
    @Published var sysPower: Double = 0
    @Published var batDirection: String = ""
    @Published var chargerRating: String = "?"

    private var timer: Timer?

    func start() {
        readNow()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.readNow() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func readNow() {
        let raw = Self.ioreg()
        guard let raw else { return }
        guard let ac = Self.extractValue(from: raw, key: "SystemPowerIn"),
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

        if let r = Self.chargerRatingFromProfiler() { chargerRating = r }
    }

    static func toSigned(_ val: UInt64) -> Int {
        if val > UInt64(Int64.max) {
            return Int(val - UInt64(Int64.max) - 1) - Int(Int64.max) - 1
        }
        return Int(val)
    }

    static func ioreg() -> String? {
        let t = Process(); t.launchPath = "/usr/sbin/ioreg"
        t.arguments = ["-r", "-c", "AppleSmartBattery"]
        let o = Pipe(); t.standardOutput = o
        try? t.run(); t.waitUntilExit()
        return String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    static func extractValue(from text: String, key: String) -> Int? {
        guard let r = text.range(of: "\"\(key)\"=") else { return nil }
        var s = ""; for ch in text[r.upperBound...] { if ch == "-" || ch.isNumber { s.append(ch) } else { break } }
        return Int(s)
    }

    static func extractUInt64(from text: String, key: String) -> UInt64? {
        guard let r = text.range(of: "\"\(key)\"=") else { return nil }
        var s = ""; for ch in text[r.upperBound...] { if ch.isNumber { s.append(ch) } else { break } }
        return UInt64(s)
    }

    static func extractVoltage(from text: String) -> Int? {
        guard let r = text.range(of: "\"Voltage\"=") else { return nil }
        var s = ""; for ch in text[r.upperBound...] { if ch.isNumber { s.append(ch) } else if ch == "," || ch == "}" { break } }
        return Int(s)
    }

    static func chargerRatingFromProfiler() -> String? {
        let t = Process(); t.launchPath = "/usr/sbin/system_profiler"
        t.arguments = ["SPPowerDataType"]
        let o = Pipe(); t.standardOutput = o
        try? t.run(); t.waitUntilExit()
        guard let text = String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: .newlines) {
            if line.contains("Wattage (W)") {
                return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}

struct PowerLabelView: View {
    @ObservedObject var monitor: PowerMonitor
    var body: some View {
        let icon = monitor.batDirection == "⚡" ? "bolt.fill" :
                   monitor.batDirection == "🔋" ? "battery.25" : "bolt"
        Label("\(monitor.sysPower, specifier: "%.1f")W", systemImage: icon)
            .task { monitor.start() }
    }
}

struct PowerMenuView: View {
    @ObservedObject var monitor: PowerMonitor
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Adapter:        \(monitor.chargerRating) W")
            Text("AC Input:       \(monitor.acPower, specifier: "%.1f") W")
            Text("Battery:        \(monitor.batPower, specifier: "%.1f") W \(monitor.batDirection)")
            Text("System:         \(monitor.sysPower, specifier: "%.1f") W")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }.padding(.horizontal, 4).frame(width: 180)
    }
}

@main
struct PowerMonitorApp: App {
    @StateObject private var monitor = PowerMonitor()
    var body: some Scene {
        MenuBarExtra {
            PowerMenuView(monitor: monitor)
        } label: {
            PowerLabelView(monitor: monitor)
        }.menuBarExtraStyle(.menu)
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

echo "==> Launching ${APP_NAME}.app ..."
open "$APP_DIR"

rm -rf "$SWIFT_SRC"
echo ""
echo "✅ Installed! PowerMonitor is now in your menu bar."
echo "   - Menu bar shows:  XX.XW ⚡/🔋"
echo "   - Click for details: Adapter / AC Input / Battery / System"
echo "   - CLI: power"
echo ""
echo "To remove:"
echo "   rm -rf /Applications/PowerMonitor.app /usr/local/bin/power"
