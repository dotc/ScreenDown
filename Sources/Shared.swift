import Foundation
import IOKit

let serviceID = "local.screendown.helper"
let settingsPath = "/Users/Shared/ScreenDown/settings.json"
let statusPath = "/var/run/local.screendown/status.json"
struct Settings: Codable {
    var paused = false
    var timeoutMinutes = 10
    init(paused: Bool = false, timeoutMinutes: Int = 10) {
        self.paused = paused
        self.timeoutMinutes = timeoutMinutes
    }
    private enum CodingKeys: String, CodingKey { case paused, timeoutMinutes }
    private enum LegacyKeys: String, CodingKey { case dryRun }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        paused = try values.decode(Bool.self, forKey: .paused)
        timeoutMinutes = try values.decode(Int.self, forKey: .timeoutMinutes)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        // Preserve the non-shutdown behavior when upgrading an older configuration.
        if try legacy.decodeIfPresent(Bool.self, forKey: .dryRun) == true { paused = true }
    }
    static func load() -> Settings? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let value = try? JSONDecoder().decode(Settings.self, from: data),
              (1...1440).contains(value.timeoutMinutes) else { return nil }
        return value
    }
    func save() throws {
        try JSONEncoder().encode(self).write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }
}
struct Status: Codable {
    var logVersion: Int? = nil
    var date = Date()
    var message: String
    var remaining: Int?
    var displays: Int
}
func displayCount() -> Int? {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDisplay"), &iterator) == KERN_SUCCESS else { return nil }
    defer { IOObjectRelease(iterator) }
    var count = 0
    while case let item = IOIteratorNext(iterator), item != 0 {
        count += 1
        IOObjectRelease(item)
    }
    return count
}
struct Monitor {
    var armed = false
    var offlineSince: TimeInterval?
    var previousTick: TimeInterval?
    var previousSettings: Settings?
    var triggered = false
    mutating func tick(now: TimeInterval, displays: Int?, settings: Settings?) -> (String, Int?, Bool) {
        defer { previousTick = now; previousSettings = settings }
        guard let settings = settings, let displays = displays else {
            offlineSince = nil; triggered = false
            return ("Unable to Read Status; Countdown Stopped", nil, false)
        }
        if let old = previousSettings,
           old.paused != settings.paused || old.timeoutMinutes != settings.timeoutMinutes {
            offlineSince = nil; triggered = false
        }
        if let previous = previousTick, now - previous > 20 || now < previous {
            offlineSince = nil; triggered = false
        }
        if displays > 0 {
            armed = true; offlineSince = nil; triggered = false
            return (settings.paused ? "Paused" : "Display Online", nil, false)
        }
        if settings.paused { offlineSince = nil; triggered = false; return ("Paused", nil, false) }
        guard armed else { return ("Waiting for a Display to Connect", nil, false) }
        if offlineSince == nil { offlineSince = now }
        let remaining = max(0, settings.timeoutMinutes * 60 - Int(now - offlineSince!))
        if remaining > 0 { return ("Display Offline; Shutdown In", remaining, false) }
        if triggered { return ("System Shutdown Requested", 0, false) }
        triggered = true
        return ("Requesting System Shutdown", 0, true)
    }
}
