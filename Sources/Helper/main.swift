import Foundation

if CommandLine.arguments.contains("--self-test") {
    let migrated = try! JSONDecoder().decode(Settings.self, from: Data(#"{"paused":false,"timeoutMinutes":5,"dryRun":true}"#.utf8))
    precondition(migrated.paused)
    let current = try! JSONDecoder().decode(Settings.self, from: Data(#"{"paused":false,"timeoutMinutes":5}"#.utf8))
    precondition(!current.paused)
    let encoded = String(data: try! JSONEncoder().encode(current), encoding: .utf8)!
    precondition(!encoded.contains("dryRun"))
    var monitor = Monitor()
    let normal = Settings(paused: false, timeoutMinutes: 1)
    precondition(!monitor.tick(now: 0, displays: 0, settings: normal).2)
    _ = monitor.tick(now: 1, displays: 1, settings: normal)
    _ = monitor.tick(now: 2, displays: 0, settings: normal)
    for t in stride(from: 7.0, through: 57.0, by: 5) { precondition(!monitor.tick(now: t, displays: 0, settings: normal).2) }
    precondition(monitor.tick(now: 62, displays: 0, settings: normal).2)
    precondition(!monitor.tick(now: 67, displays: 0, settings: normal).2)
    _ = monitor.tick(now: 68, displays: 1, settings: normal)
    precondition(monitor.tick(now: 69, displays: 0, settings: normal).1 == 60)
    let paused = Settings(paused: true, timeoutMinutes: 1)
    precondition(monitor.tick(now: 70, displays: 0, settings: paused).1 == nil)
    precondition(monitor.tick(now: 71, displays: 0, settings: normal).1 == 60)
    precondition(monitor.tick(now: 200, displays: 0, settings: normal).1 == 60)
    precondition(monitor.tick(now: 201, displays: nil, settings: normal).1 == nil)
    precondition(monitor.tick(now: 202, displays: 0, settings: nil).1 == nil)
    print("PASS: startup, countdown, one-shot, reconnect, pause, resume, wake gap, read failure")
    print("Live displays: \(displayCount().map(String.init) ?? "unknown")")
    exit(0)
}
guard getuid() == 0 else { fputs("Helper requires root.\n", stderr); exit(1) }
umask(0o022)
try FileManager.default.createDirectory(atPath: "/var/run/local.screendown", withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
var monitor = Monitor()
let logger = EventLogger()
var previousEventKey: String?
var wasCounting = false
while true {
    let settings = Settings.load()
    let count = displayCount()
    let result = monitor.tick(now: ProcessInfo.processInfo.systemUptime, displays: count, settings: settings)
    let status = Status(logVersion: 3, message: result.0, remaining: result.1, displays: count ?? -1)
    if let data = try? JSONEncoder().encode(status) {
        try? data.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
    }
    let eventKey = "\(result.0)|\(settings?.paused.description ?? "unknown")|\(settings?.timeoutMinutes ?? 0)"
    if eventKey != previousEventKey {
        let message = wasCounting && (count ?? 0) > 0 ? "Display Reconnected; Countdown Canceled" : result.0
        do {
            try logger.append(LogEvent(message: message, remaining: result.1, displays: count ?? -1))
            previousEventKey = eventKey
        } catch { NSLog("ScreenDown log write failed: %@", String(describing: error)) }
    }
    wasCounting = (result.1 ?? 0) > 0
    if result.2 {
        // Fixed executable and arguments only; settings never supply a command.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/shutdown")
        process.arguments = ["-h", "now"]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                try? logger.append(LogEvent(message: "System Shutdown Command Failed", displays: count ?? -1))
            }
        } catch {
            try? logger.append(LogEvent(message: "System Shutdown Command Failed", displays: count ?? -1))
            NSLog("ScreenDown shutdown failed: %@", String(describing: error))
        }
    }
    Thread.sleep(forTimeInterval: 5)
}
