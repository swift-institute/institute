import Foundation

enum CensusFoundation {
    static func uuidString() -> String {
        UUID().uuidString
    }

    static func temporaryRoot(name: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("census-fixture-\(name)").path
    }

    static func removeItem(atPath path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    static func createDirectory(atPath path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true
        )
    }

    static func write(_ yaml: String, toPath path: String) throws {
        try Data(yaml.utf8).write(
            to: URL(fileURLWithPath: path)
        )
    }
}
