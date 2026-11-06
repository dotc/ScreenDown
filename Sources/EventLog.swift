import Foundation

let eventLogPath = "/Library/Logs/ScreenDown/events.jsonl"
struct LogEvent: Codable {
    var date = Date()
    var message: String
    var remaining: Int?
    var displays: Int
    // Decode old metadata only; new records omit it.
    var legacySimulation: Bool? = nil
    private enum CodingKeys: String, CodingKey {
        case date, message, remaining, displays
        case legacySimulation = "dryRun"
    }
}
final class EventLogger {
    let path: String
    init(path: String = eventLogPath) { self.path = path }
    func append(_ event: LogEvent) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? NSNumber, size.intValue >= 2 * 1024 * 1024 {
            let archive = path + ".1"
            if FileManager.default.fileExists(atPath: archive) { try FileManager.default.removeItem(atPath: archive) }
            try FileManager.default.moveItem(atPath: path, toPath: archive)
        }
        if !FileManager.default.fileExists(atPath: path) {
            guard FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o644]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        var data = try JSONEncoder().encode(event)
        data.append(0x0a)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
    static func read() -> [LogEvent] {
        [eventLogPath + ".1", eventLogPath].flatMap { path -> [LogEvent] in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return [] }
            return data.split(separator: 0x0a).compactMap { try? JSONDecoder().decode(LogEvent.self, from: Data($0)) }
        }
    }
}
