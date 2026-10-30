import Foundation

/// A uniquely named temporary directory holding an empty `target`, a `live`
/// symbolic link to it and a `broken` symbolic link to `missing`.
struct BrokenSymlinkFixture {
    let root: URL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    var path: Swift.String { root.path }

    private var target: URL { root.appending(path: "target") }

    func createDirectory() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func createEmptyTarget() -> Swift.Bool {
        FileManager.default.createFile(atPath: target.path, contents: Data())
    }

    func linkLiveToTarget() throws {
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "live"),
            withDestinationURL: target
        )
    }

    func linkBrokenToMissing() throws {
        try FileManager.default.createSymbolicLink(
            atPath: root.appending(path: "broken").path,
            withDestinationPath: "missing"
        )
    }
}
