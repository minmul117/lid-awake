// LidAwake — 뚜껑을 닫아도 Mac이 잠들지 않게 해 주는 메뉴 막대 앱
// pmset disablesleep + caffeinate, 배터리 보호, 로그인 시 실행

import AppKit
import IOKit.ps
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var caffeinate: Process?
    private var timer: Timer?
    private var isOn = false

    /// 배터리 사용 중 이 % 미만이면 자동 해제 (0 = 사용 안 함)
    private var minBattery: Int {
        get { UserDefaults.standard.object(forKey: "minBattery") as? Int ?? 20 }
        set { UserDefaults.standard.set(newValue, forKey: "minBattery") }
    }

    /// 켜져 있는 동안의 동작 방식
    enum Mode: String, CaseIterable {
        case systemAndDisplay   // 시스템 + 화면 유지 (caffeinate -dims)
        case systemOnly         // 시스템만 유지, 화면은 평소처럼 꺼짐 (caffeinate -ims)

        var title: String {
            switch self {
            case .systemAndDisplay: return "시스템 + 화면 유지"
            case .systemOnly:       return "시스템만 유지 (화면은 꺼짐)"
            }
        }

        var caffeinateFlags: String {
            switch self {
            case .systemAndDisplay: return "-dims"
            case .systemOnly:       return "-ims"
            }
        }
    }

    private var mode: Mode {
        get { Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .systemAndDisplay }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mode") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        isOn = readSleepDisabled()
        if isOn { startCaffeinate() }
        updateIcon()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 앱을 끄면 항상 원래 잠자기 설정으로 되돌림
        if isOn { _ = setSleepDisabled(false) }
        stopCaffeinate()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(label(isOn ? "● 깨어 있음 (뚜껑 닫아도 유지)" : "○ 꺼짐 (평소처럼 잠자기)"))
        menu.addItem(item(isOn ? "끄기" : "켜기", #selector(toggle), key: "t"))
        menu.addItem(.separator())

        menu.addItem(label("모드"))
        for m in Mode.allCases {
            let mi = item(m.title, #selector(setMode(_:)))
            mi.representedObject = m.rawValue
            mi.state = (m == mode) ? .on : .off
            mi.indentationLevel = 1
            menu.addItem(mi)
        }
        menu.addItem(.separator())

        let p = powerInfo()
        let pct = p.percent.map { "\($0)%" } ?? "—"
        menu.addItem(label(p.onAC ? "전원 어댑터 연결됨 · \(pct)" : "배터리 사용 중 · \(pct)"))

        let guardMenu = NSMenu()
        for v in [0, 10, 20, 30] {
            let mi = item(v == 0 ? "사용 안 함" : "\(v)% 미만이면 자동 끄기", #selector(setGuard(_:)))
            mi.tag = v
            mi.state = (v == minBattery) ? .on : .off
            guardMenu.addItem(mi)
        }
        let guardItem = NSMenuItem(title: "배터리 보호", action: nil, keyEquivalent: "")
        guardItem.submenu = guardMenu
        menu.addItem(guardItem)

        if #available(macOS 13.0, *) {
            let li = item("로그인 시 실행", #selector(toggleLogin))
            li.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(li)
        }

        menu.addItem(.separator())
        menu.addItem(item("종료 (잠자기 설정 복원)", #selector(quit), key: "q"))
    }

    private func label(_ title: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.isEnabled = false
        return mi
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        return mi
    }

    private func updateIcon() {
        let name = isOn ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Lid Awake")
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.toolTip = isOn ? "Lid Awake: 켜짐 · \(mode.title)" : "Lid Awake: 꺼짐"
    }

    // MARK: - Actions

    @objc private func toggle() {
        let target = !isOn
        guard setSleepDisabled(target) else {
            notify("권한이 없어 설정을 바꾸지 못했어요")
            return
        }
        isOn = target
        target ? startCaffeinate() : stopCaffeinate()
        updateIcon()
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let m = Mode(rawValue: raw), m != mode else { return }
        mode = m
        // 켜져 있으면 새 옵션으로 caffeinate 재시작 (pmset 설정은 그대로)
        if isOn {
            stopCaffeinate()
            startCaffeinate()
        }
        updateIcon()
    }

    @objc private func setGuard(_ sender: NSMenuItem) {
        minBattery = sender.tag
        tick()
    }

    @objc private func toggleLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            notify("로그인 항목 설정 실패: \(error.localizedDescription)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Periodic check

    private func tick() {
        let p = powerInfo()
        if isOn, minBattery > 0, !p.onAC, let pct = p.percent, pct < minBattery {
            if setSleepDisabled(false) {
                isOn = false
                stopCaffeinate()
                notify("배터리 \(pct)% — 잠자기 방지를 껐습니다")
            }
        }
        // 터미널 등 외부에서 바꾼 상태와 동기화
        let actual = readSleepDisabled()
        if actual != isOn {
            isOn = actual
            actual ? startCaffeinate() : stopCaffeinate()
        }
        updateIcon()
    }

    // MARK: - pmset / caffeinate

    private func readSleepDisabled() -> Bool {
        let out = run("/usr/bin/pmset", ["-g"]).output
        for line in out.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.first == "SleepDisabled" { return parts.last == "1" }
        }
        return false
    }

    /// 1) sudoers에 등록돼 있으면 암호 없이, 2) 아니면 관리자 암호 창으로
    private func setSleepDisabled(_ on: Bool) -> Bool {
        let v = on ? "1" : "0"
        if run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", v]).status == 0 {
            return true
        }
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(v)\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        return err == nil
    }

    private func startCaffeinate() {
        guard caffeinate == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -w: 이 앱이 종료되면 caffeinate도 같이 종료
        p.arguments = [mode.caffeinateFlags, "-w", String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try p.run()
            caffeinate = p
        } catch {
            caffeinate = nil
        }
    }

    private func stopCaffeinate() {
        if let p = caffeinate, p.isRunning {
            p.terminate()
            p.waitUntilExit()
        }
        caffeinate = nil
    }

    // MARK: - Helpers

    private func powerInfo() -> (onAC: Bool, percent: Int?) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return (true, nil) }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        let onAC = (type ?? kIOPSACPowerValue) == kIOPSACPowerValue
        var pct: Int?
        if let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                if let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                   let cur = d[kIOPSCurrentCapacityKey] as? Int,
                   let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 {
                    pct = cur * 100 / max
                }
            }
        }
        return (onAC, pct)
    }

    private func notify(_ message: String) {
        let safe = message.replacingOccurrences(of: "\"", with: "'")
        _ = run("/usr/bin/osascript", ["-e", "display notification \"\(safe)\" with title \"Lid Awake\""])
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
