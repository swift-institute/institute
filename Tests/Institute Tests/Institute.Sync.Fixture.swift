import File_System
import Foundation
import Git_Foundation

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Sync {
    struct Fixture {
        let base: URL
        let root: URL
        let source: URL
        let remote: URL
        /// The canonical, sibling materialization location.
        let local: URL
        /// The retired location inside the checkout. It must stay untouched.
        let legacy: URL
        let client: Git.Client

        init() throws {
            let temporary =
                FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(
                at: temporary,
                withIntermediateDirectories: true
            )
            base = URL(
                fileURLWithPath:
                    try File.System.Canonical.resolve(File.Path(temporary.path)).description,
                isDirectory: true
            )
            root = base.appending(path: "Institute")
            source = base.appending(path: "source")
            remote = base.appending(path: "remote.git")
            local = base.appending(path: "swift-foundations/swift-example")
            legacy = root.appending(path: "swift-foundations/swift-example")
            client = .init()

            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: base.appending(path: "swift-foundations"),
                withIntermediateDirectories: true
            )
            try Self.package(
                at: root,
                name: "institute-application",
                targets: [
                    ("Institute Application Source", false),
                    ("Institute Application Source Tests", true),
                ]
            )
            try Self.package(
                at: base.appending(path: "institute"),
                name: "institute",
                targets: [
                    ("Institute Source Workspace", false),
                    ("Institute Source Profile", false),
                    ("Institute Source", false),
                ]
            )
            try Self.package(
                at: base.appending(path: "institute-continuous-integration"),
                name: "institute-continuous-integration",
                targets: [("Institute Continuous Integration Source", false)]
            )
            try client.initialize(at: source.path, bare: false)
            try Self.package(
                at: source,
                name: "swift-example",
                targets: [
                    ("Source Measurement", false),
                    ("Source Profile", false),
                    ("Source Execution", false),
                    ("Source Report", false),
                    ("Source Repair", false),
                    ("Institute Linter Rule Manifest", false),
                ]
            )
            try command(["config", "user.email", "workspace@swift.institute"], at: source)
            try command(["config", "user.name", "Institute Tests"], at: source)
            try command(["branch", "-M", "main"], at: source)
            try commit("first", contents: "first\n", at: source)
            try client.clone(source.path, branch: "main", bare: true, to: remote.path)
            try client.clone(remote.path, branch: "main", to: local.path)
        }
    }
}

extension Institute.Sync.Fixture {
    func remove() {
        try? FileManager.default.removeItem(at: base)
    }

    func push(_ message: Swift.String, contents: Swift.String) throws {
        try commit(message, contents: contents, at: source)
        try command(["push", remote.path, "main"], at: source)
    }

    /// Moves `local` off `main` onto a fresh branch, without touching
    /// `origin`. Used to reach `inspect`'s origin check while stopping the
    /// inspection at the following branch check, before it needs
    /// `repository.url` to be a reachable remote (`probe`/`fetch`) — the
    /// origin string itself only ever has to be text `git remote` can store.
    func checkout(_ branch: Swift.String) throws {
        try command(["checkout", "-b", branch], at: local)
    }

    /// Rewrites `local`'s configured `origin` URL to an arbitrary string,
    /// independent of what it actually resolves to. `git remote set-url`
    /// only writes config text; it performs no reachability check, which is
    /// what makes it usable to stage a same-repository-different-transport
    /// (or genuinely-different-repository) origin string for `inspect`.
    func setOrigin(_ url: Swift.String) throws {
        try command(["remote", "set-url", "origin", url], at: local)
    }

    func replaceRemote() throws {
        let replacement = base.appending(path: "replacement")
        try client.initialize(at: replacement.path, bare: false)
        try command(["config", "user.email", "workspace@swift.institute"], at: replacement)
        try command(["config", "user.name", "Institute Tests"], at: replacement)
        try command(["branch", "-M", "main"], at: replacement)
        try commit("replacement", contents: "replacement\n", at: replacement)
        try command(["push", "--force", remote.path, "main"], at: replacement)
    }

    func application() throws -> Institute.Sync {
        let directory = try File.Directory(validating: root.path)
        let repository = Institute.Repository(
            name: "swift-example",
            url: remote.path,
            organization: "swift-foundations",
            layer: .foundations
        )
        return Institute.Sync(
            root: try Institute.Root(checkout: directory),
            selection: .init(repositories: [repository], origin: .committed(count: 1)),
            client: client
        )
    }

    func state() throws -> State {
        .init(
            head: try client.head(at: local.path),
            origin: try client.head("origin/main", at: local.path),
            fetch: try? Data(contentsOf: local.appending(path: ".git/FETCH_HEAD")),
            status: try client.status(at: local.path),
            workspace: try? Data(
                contentsOf: root.appending(
                    path: "institute interim.xcworkspace/contents.xcworkspacedata"
                )
            ),
            ledger: try? Data(contentsOf: root.appending(path: ".workspace/compositions.json")),
            canonical: try entries(at: base.appending(path: "swift-foundations")),
            legacy: try entries(at: root.appending(path: "swift-foundations"))
        )
    }

    func residue() throws -> [Swift.String] {
        try FileManager.default.contentsOfDirectory(
            atPath: base.path
        )
        .filter { $0.hasPrefix(".workspace-") }
        .sorted()
    }

    private func entries(at directory: URL) throws -> [Swift.String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.subpathsOfDirectory(atPath: directory.path).sorted()
    }

    private func commit(
        _ message: Swift.String,
        contents: Swift.String,
        at repository: URL
    ) throws {
        try contents.write(
            to: repository.appending(path: "Fixture.txt"),
            atomically: true,
            encoding: .utf8
        )
        try command(["add", "--all"], at: repository)
        try command(["commit", "-m", message], at: repository)
    }

    private func command(_ arguments: [Swift.String], at directory: URL) throws {
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableNotLoadable)
        }
    }

    private static func package(
        at directory: URL,
        name: Swift.String,
        targets: [(name: Swift.String, test: Swift.Bool)]
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var declarations: [Swift.String] = []
        for (index, target) in targets.enumerated() {
            let path = "Targets/\(index)"
            let targetDirectory = directory.appending(path: path)
            try FileManager.default.createDirectory(
                at: targetDirectory,
                withIntermediateDirectories: true
            )
            try Data("public enum Fixture\(index) {}\n".utf8).write(
                to: targetDirectory.appending(path: "Fixture.swift")
            )
            declarations.append(
                ".\(target.test ? "testTarget" : "target")(name: \"\(target.name)\", path: \"\(path)\")"
            )
        }
        let manifest = """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "\(name)",
                targets: [
                    \(declarations.joined(separator: ",\n        "))
                ]
            )
            """
        try Data(manifest.utf8).write(to: directory.appending(path: "Package.swift"))
    }
}
