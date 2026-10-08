import Foundation
import Git_Foundation

/// Foundation-only file and path operations for the Testing files of this
/// target: String paths, byte arrays and String indices in and out, the
/// same Foundation calls the tests made directly before.
enum MainFixtureFiles {
    static func uniqueName() -> Swift.String { UUID().uuidString }

    static func temporaryPath(_ name: Swift.String) -> Swift.String {
        FileManager.default.temporaryDirectory.appending(path: name).path
    }

    static func resolvedTemporaryPath(_ name: Swift.String) -> Swift.String {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appending(path: name).path
    }

    static var temporaryRoot: Swift.String { NSTemporaryDirectory() }

    static func join(_ base: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: base).appending(path: relative).path
    }

    static func parent(of path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    static func sibling(of filePath: Swift.String, _ relative: Swift.String) -> Swift.String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent().appending(path: relative).path
    }

    static func lastComponent(of path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func standardized(_ path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    static func resolvingSymlinks(_ path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    static func createDirectory(_ path: Swift.String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    static func remove(_ path: Swift.String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    /// The build products directory holding this test bundle and the
    /// executables the test targets depend on.
    static var productsDirectory: Swift.String {
        let bundle = Bundle(for: ProductsAnchor.self).bundleURL
        #if os(macOS)
            return bundle.deletingLastPathComponent().path
        #else
            return bundle.path
        #endif
    }

    private final class ProductsAnchor {}

    /// The compiled fixture linter built from `Institute Lint Fixture Linter`.
    static var fixtureLinter: Swift.String {
        #if os(Windows)
            join(productsDirectory, "Institute Lint Fixture Linter.exe")
        #else
            join(productsDirectory, "Institute Lint Fixture Linter")
        #endif
    }

    static func exists(_ path: Swift.String) -> Swift.Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func isDirectory(_ path: Swift.String) -> Swift.Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory)
            && directory.boolValue
    }

    static func contents(ofDirectory path: Swift.String) throws -> [Swift.String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }

    static func copy(_ source: Swift.String, to destination: Swift.String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }

    static func move(_ source: Swift.String, to destination: Swift.String) throws {
        try FileManager.default.moveItem(atPath: source, toPath: destination)
    }

    static func createSymbolicLink(atPath path: Swift.String, destinationPath: Swift.String) throws {
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: destinationPath)
    }

    @discardableResult
    static func createFile(_ path: Swift.String, contents: [Swift.UInt8]?) -> Swift.Bool {
        FileManager.default.createFile(atPath: path, contents: contents.map { Data($0) })
    }

    static func readBytes(_ path: Swift.String) throws -> [Swift.UInt8] {
        [Swift.UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
    }

    static func readBytesIfPresent(_ path: Swift.String) -> [Swift.UInt8]? {
        FileManager.default.contents(atPath: path).map { [Swift.UInt8]($0) }
    }

    static func readStrictUTF8(_ path: Swift.String) throws -> Swift.String {
        try Swift.String(contentsOfFile: path, encoding: .utf8)
    }

    static func write(_ text: Swift.String, toFile path: Swift.String) throws {
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func write(bytes: [Swift.UInt8], to path: Swift.String) throws {
        try Data(bytes).write(to: URL(fileURLWithPath: path))
    }

    static func writeAtomically(bytes: [Swift.UInt8], to path: Swift.String) throws {
        try Data(bytes).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    static func setPermissions(_ path: Swift.String, posix: Swift.Int) throws {
        try FileManager.default.setAttributes([.posixPermissions: posix], ofItemAtPath: path)
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

    static func components(of text: Swift.String, separatedBy separator: Swift.String) -> [Swift.String] {
        text.components(separatedBy: separator)
    }

    static var fileWriteUnknown: any Swift.Error { CocoaError(.fileWriteUnknown) }

    static var fileNoSuchFile: any Swift.Error { CocoaError(.fileNoSuchFile) }

    static func createSymbolicLink(_ path: Swift.String, toURLOf destination: Swift.String) throws {
        try FileManager.default.createSymbolicLink(
            at: URL(fileURLWithPath: path),
            withDestinationURL: URL(fileURLWithPath: destination)
        )
    }

    static func write(_ text: Swift.String, toURLPath path: Swift.String) throws {
        try text.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    /// The resolved git in `directory`, its standard output and error read
    /// through one pipe; a nonzero exit throws ``GitFailure`` carrying the
    /// arguments, status and that output.
    static func gitRequiringSuccess(_ arguments: [Swift.String], in directory: Swift.String) throws {
        try gitRequiringSuccess(
            arguments,
            currentDirectory: URL(fileURLWithPath: directory, isDirectory: true)
        )
    }

    /// The same git run with the working directory constructed exactly as
    /// `FileManager.default.temporaryDirectory.appending(path: name)`.
    static func gitRequiringSuccess(_ arguments: [Swift.String], inTemporary name: Swift.String) throws {
        try gitRequiringSuccess(
            arguments,
            currentDirectory: FileManager.default.temporaryDirectory.appending(path: name)
        )
    }

    /// The same git run with the working directory constructed exactly as
    /// `FileManager.default.temporaryDirectory.appending(path: name).appending(path: child)`.
    static func gitRequiringSuccess(
        _ arguments: [Swift.String],
        inTemporary name: Swift.String,
        child: Swift.String
    ) throws {
        try gitRequiringSuccess(
            arguments,
            currentDirectory: FileManager.default.temporaryDirectory
                .appending(path: name)
                .appending(path: child)
        )
    }

    struct GitFailure: Swift.Error, Swift.CustomStringConvertible {
        let arguments: [Swift.String]
        let directory: Swift.String
        let status: Swift.Int32
        let output: Swift.String

        var description: Swift.String {
            "git \(arguments.joined(separator: " ")) in \(directory) exited \(status): \(output)"
        }
    }

    static func gitRequiringSuccess(
        _ arguments: [Swift.String],
        currentDirectory: URL
    ) throws {
        let process = Foundation.Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: Git.Client.installed)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let diagnostics = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitFailure(
                arguments: arguments,
                directory: currentDirectory.path,
                status: process.terminationStatus,
                output: Swift.String(decoding: diagnostics, as: Swift.UTF8.self)
            )
        }
    }

    static func readStrictUTF8URL(_ path: Swift.String) throws -> Swift.String {
        try Swift.String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    static func posixPermissions(_ path: Swift.String) throws -> Swift.Int? {
        try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Swift.Int
    }

    static func isSymbolicLink(_ path: Swift.String) throws -> Swift.Bool {
        try FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType
            == .typeSymbolicLink
    }

    static func directoryPath(_ path: Swift.String) -> Swift.String {
        URL(fileURLWithPath: path, isDirectory: true).path
    }
}
