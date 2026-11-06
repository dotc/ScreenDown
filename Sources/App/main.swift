import AppKit

func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var timer: Timer?
    var logWindow: NSWindow?
    var logText: NSTextView?
    var lastLogContents = ""
    var settings = Settings.load() ?? Settings()
    let loginID = "local.screendown.app"
    var loginURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(loginID).plist") }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            try FileManager.default.createDirectory(atPath: "/Users/Shared/ScreenDown", withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try settings.save()
        } catch { alert(L("Unable to Save Settings"), String(describing: error)) }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "ScreenDown")
        rebuild()
        if CommandLine.arguments.contains("--update-helper") {
            DispatchQueue.main.async { self.install() }
        }
        if CommandLine.arguments.contains("--show-help") {
            DispatchQueue.main.async { self.showHelp() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.rebuild() }
        if !FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(serviceID)") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.install() }
        }
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector? = nil, tag: Int = 0, checked: Bool = false) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; entry.tag = tag; entry.state = checked ? .on : .off
        menu.addItem(entry)
    }
    func rebuild() {
        refreshLogs()
        let menu = NSMenu()
        add(menu, L("ScreenDown · Shut Down After Screen Off"))
        var statusText = L("Background helper is not running")
        var indicator = settings.paused ? "Ⅱ" : "OFF"
        var modeText = settings.paused ? L("Paused") : L("Background helper is not running")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: statusPath)),
           let status = try? JSONDecoder().decode(Status.self, from: data), Date().timeIntervalSince(status.date) < 20 {
            statusText = settings.paused ? L("Paused") : L(status.message)
            if (status.logVersion ?? 0) < 3 {
                statusText = L("Background helper needs an update")
            }
            if !settings.paused {
                if (status.logVersion ?? 0) < 3 || status.message == "Unable to Read Status; Countdown Stopped" {
                    indicator = "OFF"
                } else if status.message == "Paused" {
                    indicator = "…"
                    modeText = L("Applying Settings")
                } else {
                    indicator = "ON"
                    modeText = L("Automatic Shutdown Enabled")
                }
            }
            if !settings.paused, let remaining = status.remaining { statusText += " \(remaining / 60):\(String(format: "%02d", remaining % 60))" }
        }
        add(menu, statusText)
        if let button = item.button {
            button.title = " " + indicator
            button.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
            button.imagePosition = .imageLeading
            button.toolTip = "ScreenDown: \(modeText) · \(statusText)"
            button.setAccessibilityLabel("ScreenDown: \(modeText) · \(statusText)")
        }
        menu.addItem(.separator())
        add(menu, settings.paused ? L("Resume Monitoring") : L("Pause Monitoring"), #selector(togglePause))
        let timeout = NSMenuItem(title: LF("Offline Timeout: %d min", settings.timeoutMinutes), action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for value in [1, 5, 10, 20, 30, 60] { add(choices, LF("%d min", value), #selector(changeTimeout(_:)), tag: value, checked: settings.timeoutMinutes == value) }
        add(choices, L("Custom…"), #selector(customTimeout))
        timeout.submenu = choices; menu.addItem(timeout)
        add(menu, L("Launch at Login"), #selector(toggleLogin), checked: FileManager.default.fileExists(atPath: loginURL.path))
        menu.addItem(.separator())
        add(menu, L("Install / Update Helper…"), #selector(install))
        add(menu, L("View Logs…"), #selector(showLogs))
        add(menu, L("Help…"), #selector(showHelp))
        add(menu, L("Uninstall Helper…"), #selector(uninstall))
        add(menu, L("Quit and Pause Monitoring"), #selector(quit))
        item.menu = menu
    }
    @objc func showLogs() {
        if logWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 460), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L("ScreenDown Logs")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 520, height: 280)
            let scroll = NSScrollView(frame: window.contentView!.bounds)
            scroll.autoresizingMask = [.width, .height]
            scroll.hasVerticalScroller = true
            let text = NSTextView(frame: scroll.bounds)
            text.isEditable = false
            text.isSelectable = true
            text.isRichText = false
            text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            text.textContainerInset = NSSize(width: 12, height: 12)
            text.autoresizingMask = [.width]
            text.isVerticallyResizable = true
            text.isHorizontallyResizable = false
            text.textContainer?.widthTracksTextView = true
            scroll.documentView = text
            window.contentView?.addSubview(scroll)
            window.center()
            logWindow = window; logText = text
        }
        refreshLogs(force: true)
        NSApp.activate(ignoringOtherApps: true)
        logWindow?.makeKeyAndOrderFront(nil)
    }
    func refreshLogs(force: Bool = false) {
        guard force || logWindow?.isVisible == true, let text = logText else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .short; formatter.timeStyle = .medium
        var lines = [L("Logs are saved automatically by the helper and remain available after reconnecting a display or restarting."), eventLogPath, ""]
        let events = EventLogger.read().suffix(500)
        if events.isEmpty { lines.append(L("No logs yet. If you just updated the app, install / update the helper to enable logging.")) }
        for event in events {
            var line = "[\(formatter.string(from: event.date))] \(L(event.message))"
            if event.legacySimulation == true { line += " [" + L("Historical Simulation") + "]" }
            if let remaining = event.remaining { line += " · " + LF("%d seconds remaining", remaining) }
            lines.append(line)
        }
        let contents = lines.joined(separator: "\n")
        if force || contents != lastLogContents {
            text.string = contents
            text.scrollToEndOfDocument(nil)
            lastLogContents = contents
        }
    }
    func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.icon = ScreenDownIcon.image()
        return alert
    }
    func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = makeAlert(); a.messageText = title; a.informativeText = text; a.addButton(withTitle: L("OK")); a.runModal()
    }
    func save() { do { try settings.save(); rebuild() } catch { alert(L("Save Failed"), String(describing: error)) } }
    @objc func togglePause() { settings.paused.toggle(); save() }
    @objc func changeTimeout(_ sender: NSMenuItem) { settings.timeoutMinutes = sender.tag; save() }
    @objc func customTimeout() {
        let a = makeAlert(); a.messageText = L("How long should ScreenDown wait?"); a.informativeText = L("Enter 1–1440 minutes. Changing this resets the countdown.")
        let input = NSTextField(string: String(settings.timeoutMinutes)); input.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        a.accessoryView = input; a.addButton(withTitle: L("Save")); a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            guard let value = Int(input.stringValue), (1...1440).contains(value) else { alert(L("Invalid Timeout"), L("Enter a whole number from 1 to 1440.")); return }
            settings.timeoutMinutes = value; save()
        }
    }
    @objc func toggleLogin() {
        do {
            if FileManager.default.fileExists(atPath: loginURL.path) { try FileManager.default.removeItem(at: loginURL) }
            else {
                try FileManager.default.createDirectory(at: loginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let plist: [String: Any] = ["Label": loginID, "ProgramArguments": [Bundle.main.executablePath!], "RunAtLoad": true, "LimitLoadToSessionType": "Aqua"]
                try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: loginURL, options: .atomic)
            }
            rebuild()
        } catch { alert(L("Unable to Change Launch at Login"), String(describing: error)) }
    }
    func admin(_ mode: String) -> Bool {
        guard let path = Bundle.main.path(forResource: "install", ofType: "sh") else { return false }
        let command = "/bin/bash \(shellQuote(path)) \(shellQuote(mode)) \(getuid()) \(getgid())"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSApp.activate(ignoringOtherApps: true)
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
        if let error = error { alert(L("Operation Did Not Complete"), error[NSAppleScript.errorMessage] as? String ?? String(describing: error)); return false }
        return true
    }
    @objc func install() {
        let a = makeAlert(); a.messageText = L("Install ScreenDown Helper"); a.informativeText = L("The helper monitors displays and shuts down your Mac when the timeout expires. Installation requires administrator approval. Pause monitoring from the menu whenever needed.")
        a.addButton(withTitle: L("Install")); a.addButton(withTitle: L("Later"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn, admin("install") {
            if !FileManager.default.fileExists(atPath: loginURL.path) { toggleLogin() }
            rebuild()
            alert(L("Helper Installed"), LF("Launch at login is enabled. Current mode: %@. Click the display icon in the menu bar to change settings.", settings.paused ? L("Paused") : L("Automatic Shutdown Enabled")))
        }
    }
    @objc func uninstall() {
        settings.paused = true; save()
        if admin("uninstall") {
            try? FileManager.default.removeItem(at: loginURL)
            alert(L("Helper Uninstalled"), L("Launch at login is disabled. Quit and delete ScreenDown.app to remove the app. Settings remain in /Users/Shared/ScreenDown."))
        }
    }
    @objc func showHelp() { alert("ScreenDown", L("The countdown starts when all displays go offline and cancels when any display reconnects. A display must be detected after startup before monitoring is armed. Pausing, changing settings, or waking from sleep resets the countdown.\n\nWhen monitoring is enabled, the timeout triggers system shutdown. Pause monitoring to disable it. Quitting pauses monitoring; resume it manually when you reopen the app.\n\nUnplugging a display or disconnecting its power also counts as offline. The helper starts at boot; the menu bar app starts at login.")) }
    @objc func quit() { settings.paused = true; save(); NSApp.terminate(nil) }
}
if CommandLine.arguments.contains("--diagnose-localization") {
    let snapshot: [String: Any] = [
        "languages": Bundle.main.preferredLocalizations,
        "online": L("Display Online"),
        "pause": L("Pause Monitoring"),
        "timeout": LF("Offline Timeout: %d min", 10)
    ]
    let data = try! JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)
    exit(0)
}
let application = NSApplication.shared
let delegate = App()
application.delegate = delegate
application.run()
