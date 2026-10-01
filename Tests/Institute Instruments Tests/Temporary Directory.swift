import Foundation

enum TemporaryDirectory {
    static func make(
        prefix: Swift.String,
        creating relatives: [Swift.String] = []
    ) throws -> Swift.String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        for directory in relatives.isEmpty ? [root] : relatives.map(root.appendingPathComponent) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return root.path
    }
}
