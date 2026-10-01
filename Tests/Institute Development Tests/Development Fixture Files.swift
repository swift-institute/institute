import Foundation

enum DevelopmentFixtureFiles {
    static func temporaryPath(resolvingSymlinks: Swift.Bool, _ name: Swift.String) -> Swift.String {
        let temporary = FileManager.default.temporaryDirectory
        return (resolvingSymlinks ? temporary.resolvingSymlinksInPath() : temporary)
            .appending(path: name).path
    }

    static func uniqueName() -> Swift.String { UUID().uuidString }

    static func join(_ base: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: base).appending(path: relative).path
    }

    static func lastComponent(of path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func sibling(of filePath: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent().appending(path: relative).path
    }

    static func standardizedResolved(_ base: Swift.String, _ reference: Swift.String) -> Swift.String {
        URL(fileURLWithPath: base)
            .appending(path: reference)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    static func earliestRange(
        of literal: Swift.String,
        in text: Swift.String
    ) -> Swift.Range<Swift.String.Index>? {
        text.range(of: literal)
    }

    static func replacingAll(
        _ target: Swift.String,
        with replacement: Swift.String,
        in text: Swift.String
    ) -> Swift.String {
        text.replacingOccurrences(of: target, with: replacement)
    }

    static func createDirectory(_ path: Swift.String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    static func remove(_ path: Swift.String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    static func exists(_ path: Swift.String) -> Swift.Bool {
        FileManager.default.fileExists(atPath: path)
    }

    @discardableResult
    static func createFile(_ path: Swift.String, contents: [Swift.UInt8]) -> Swift.Bool {
        FileManager.default.createFile(atPath: path, contents: Data(contents))
    }

    static func copy(_ source: Swift.String, to destination: Swift.String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }

    static func createSymbolicLink(_ path: Swift.String, to destination: Swift.String) throws {
        try FileManager.default.createSymbolicLink(
            at: URL(fileURLWithPath: path),
            withDestinationURL: URL(fileURLWithPath: destination)
        )
    }

    static func readStrictUTF8(_ path: Swift.String) throws -> Swift.String {
        try Swift.String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    static func readBytes(_ path: Swift.String) throws -> [Swift.UInt8] {
        [Swift.UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
    }

    static func write(_ text: Swift.String, to path: Swift.String) throws {
        try text.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    static func write(bytes: [Swift.UInt8], to path: Swift.String) throws {
        try Data(bytes).write(to: URL(fileURLWithPath: path))
    }

    static func directoryPath(_ path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path, isDirectory: true).path
    }

    static func createSymbolicLink(atPath path: Swift.String, destinationPath: Swift.String) throws {
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: destinationPath)
    }

    static func readStrictUTF8File(_ path: Swift.String) throws -> Swift.String {
        try Swift.String(contentsOfFile: path, encoding: .utf8)
    }

    static func writeFile(_ text: Swift.String, toFile path: Swift.String) throws {
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func git(_ arguments: [Swift.String], in directory: Swift.String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}
