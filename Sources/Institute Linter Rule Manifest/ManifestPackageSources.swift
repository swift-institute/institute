internal import File_System
package import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
internal import Synchronization

/// The facts of every source file of a package on disk, read once per package root: its manifest's graph, and for
/// each target that is not a test target the files of its folder, by their path relative to the root.
package struct ManifestPackageSources: Sendable {
    package let graph: ManifestGraph
    /// The files each target that is not a test target owns, sorted, relative to the root.
    package let files: [Swift::String: [Swift::String]]
    package let facts: [Swift::String: ManifestSourceFacts]
    /// The target that owns each file: of two targets whose folders hold it, the one with the deeper folder.
    private let owners: [Swift::String: Swift::String]
    /// Every file of a target that is not a test target, sorted, once.
    package let paths: [Swift::String]

    private init(graph: ManifestGraph, files: [Swift::String: [Swift::String]], facts: [Swift::String: ManifestSourceFacts]) {
        self.graph = graph
        self.facts = facts
        var owners: [Swift::String: Swift::String] = [:]
        for target in graph.targets.sorted(by: { $0.directory.count < $1.directory.count }) {
            for file in files[target.name] ?? [] { owners[file] = target.name }
        }
        self.owners = owners
        self.paths = owners.keys.sorted()
        var owned: [Swift::String: [Swift::String]] = [:]
        for file in paths {
            if let owner = owners[file] { owned[owner, default: []].append(file) }
        }
        self.files = owned
    }
}

extension ManifestPackageSources {
    private static let cache = Mutex<[Swift::String: ManifestPackageSources]>([:])

    /// The sources of the package `source` is in, when the package is on disk. A run over `.` names its files
    /// `./Sources/…`; then the package is the working directory.
    package static func of(_ source: borrowing Lint.Source.Parsed) -> Self? {
        if let root = Lint.Scope.File.root(of: source) { return of(root: root) }
        let file = Swift::String(source.file.filePath.map { $0 == "\\" ? "/" : $0 })
        let relative = relative(source)
        guard file.hasPrefix("./"), !relative.isEmpty, file.hasSuffix("/" + relative) else { return nil }
        let root = Swift::String(file.dropLast(relative.count + 1))
        guard Lint.Scope.File.isFile(root + "/Package.swift") else { return nil }
        return of(root: root)
    }

    package static func of(root: Swift::String) -> Self? {
        if let hit = cache.withLock({ $0[root] }) { return hit }
        guard let text = Lint.Scope.File.text(at: root + "/Package.swift") else { return nil }
        let graph = ManifestGraph(tree: Parser.parse(source: text))
        var files: [Swift::String: [Swift::String]] = [:]
        var facts: [Swift::String: ManifestSourceFacts] = [:]
        for target in graph.targets where target.kind != .test && target.kind != .other {
            guard let directory = try? File.Directory(validating: root + "/" + target.directory) else { continue }
            let paths = Lint.Scope.File.swiftFiles(under: directory).map { path in
                Swift::String(Swift::String(path.map { $0 == "\\" ? "/" : $0 }).dropFirst(root.count + 1))
            }
            files[target.name] = paths
            for path in paths where facts[path] == nil {
                guard let text = Lint.Scope.File.text(at: root + "/" + path) else { continue }
                facts[path] = ManifestSourceFacts(tree: Parser.parse(source: text))
            }
        }
        let sources = Self(graph: graph, files: files, facts: facts)
        cache.withLock { $0[root] = sources }
        return sources
    }

    /// The path of `source` relative to its package root, written with `/` and without `.` components.
    package static func relative(_ source: borrowing Lint.Source.Parsed) -> Swift::String {
        source.path.underlying.split(separator: "/", omittingEmptySubsequences: true).filter { $0 != "." }
            .joined(separator: "/")
    }

    /// The target whose folder holds `path`, relative to the root.
    package func target(containing path: Swift::String) -> ManifestGraph.Target? {
        owners[path].flatMap(graph.target(named:))
    }
}
