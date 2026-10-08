import Foundation

enum FixtureFiles {
    static func sibling(of filePath: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent()
            .appendingPathComponent(relative).path
    }

    static func ancestor(of filePath: Swift.String, levels: Swift.Int) -> Swift.String {
        var url = URL(fileURLWithPath: filePath)
        for _ in 0..<levels { url.deleteLastPathComponent() }
        return url.path
    }

    static func join(_ base: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: base).appending(path: relative).path
    }

    static func parent(of path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    static func lastComponent(of path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static var temporaryRoot: Swift.String { NSTemporaryDirectory() }

    static func uniqueName() -> Swift.String { UUID().uuidString }

    static func temporaryPath(_ name: Swift.String) -> Swift.String {
        FileManager.default.temporaryDirectory.appending(path: name).path
    }

    static func createDirectory(_ path: Swift.String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true
        )
    }

    static func remove(_ path: Swift.String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    static func exists(_ path: Swift.String) -> Swift.Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func copy(_ source: Swift.String, to destination: Swift.String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }

    static func read(_ path: Swift.String) throws -> Swift.String {
        try Swift.String(contentsOfFile: path, encoding: .utf8)
    }

    static func write(_ text: Swift.String, to path: Swift.String) throws {
        try text.write(toFile: path, atomically: false, encoding: .utf8)
    }

    static func write(bytes: [Swift.UInt8], to path: Swift.String) throws {
        try Data(bytes).write(to: URL(fileURLWithPath: path))
    }

    static func relativeFiles(under root: Swift.String) -> [Swift.String]? {
        FileManager.default.enumerator(atPath: root).map { $0.compactMap { $0 as? Swift.String } }
    }

    static func subdirectories(of path: Swift.String) throws -> [Swift.String] {
        try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .map(\.path)
    }

    static var setupFailure: any Swift.Error { CocoaError(.fileWriteUnknown) }
}
