// DIAGNOSTIC BRANCH ONLY (institute#21): never merged.
// Traces every spawn site #64 changed, with unbuffered writes, and turns a
// stuck child into a fast, named failure instead of a silent hang.

import Foundation

public enum InstituteDiagnosticSpawnTrace {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var live: [Int: (label: Swift.String, start: Date)] = [:]
    nonisolated(unsafe) private static var next = 0
    nonisolated(unsafe) private static var watching = false

    private static func emit(_ line: Swift.String) {
        FileHandle.standardError.write(Data("[spawn-trace \(Date().timeIntervalSince1970)] \(line)\n".utf8))
    }

    public static func begin(
        _ site: Swift.String,
        _ program: Swift.String,
        _ arguments: [Swift.String],
        _ directory: Swift.String?
    ) -> Int {
        let label = "\(site): \(program) \(arguments.joined(separator: " ")) [in \(directory ?? "-")]"
        lock.lock()
        next += 1
        let id = next
        live[id] = (label, Date())
        let startWatchdog = !watching
        watching = true
        lock.unlock()
        emit("begin #\(id) \(label)")
        if startWatchdog {
            let thread = Thread {
                var beat = 0
                while true {
                    Thread.sleep(forTimeInterval: 15)
                    beat += 1
                    lock.lock()
                    let snapshot = live.sorted { $0.key < $1.key }
                    lock.unlock()
                    let now = Date()
                    if beat % 4 == 0 { emit("watchdog alive, \(snapshot.count) live spawn(s)") }
                    for (id, entry) in snapshot {
                        let age = now.timeIntervalSince(entry.start)
                        if age > 90 { emit("STUCK #\(id) after \(Int(age)) s: \(entry.label)") }
                        if age > 240 {
                            emit("ABORT: spawn #\(id) exceeded 240 s; exiting the test process")
                            exit(97)
                        }
                    }
                }
            }
            thread.start()
        }
        return id
    }

    public static func end(_ id: Int) {
        lock.lock()
        let entry = live.removeValue(forKey: id)
        lock.unlock()
        if let entry {
            emit("end #\(id) after \(Swift.String(format: "%.2f", Date().timeIntervalSince(entry.start))) s")
        }
    }
}
