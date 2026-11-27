public import Institute_Model
internal import Async_Fanout
internal import File_System
internal import Git_Foundation
internal import Package_Manager

extension Institute.Inventory {
    public struct Configuration: Sendable {
        /// An absolute directory.
        public var root: Swift.String
        /// The directory the tables are written into; created when missing.
        public var output: Swift.String
        /// Path prefixes relative to the root that are not walked.
        public var excluded: [Swift.String]
        /// How many manifests are evaluated, and files parsed, at once.
        public var jobs: Swift.Int

        public init(root: Swift.String, output: Swift.String, excluded: [Swift.String] = [], jobs: Swift.Int? = nil) {
            self.root = root.count > 1 && root.hasSuffix("/") ? Swift.String(root.dropLast()) : root
            self.output = output
            self.excluded = excluded
            self.jobs = jobs ?? Async.Fanout.processors
        }
    }

    public struct Summary: Sendable {
        public var repositories = 0
        public var packages = 0
        public var targets = 0
        public var files = 0
        public var types = 0
        public var references = 0
        public var resolved = 0
        public var ambiguous = 0
        public var unresolved = 0
        public var failures = 0

        public var description: Swift.String {
            "\(repositories) repositories, \(packages) packages, \(targets) targets, \(files) files, "
                + "\(types) types, \(references) references (aggregated rows: \(resolved) resolved, "
                + "\(ambiguous) of them ambiguous, \(unresolved) unresolved), \(failures) failures"
        }
    }
}

extension Institute.Inventory {
    struct Repository: Sendable {
        var path: Swift.String
        var origin: Swift.String
        var head: Swift.String
        var dirty: Swift.Bool
    }

    struct Target: Sendable {
        var package: Swift.Int
        var manifest: Package.Manifest.Target
        var name: Swift.String
        /// The source directory relative to the package, empty when none exists.
        var path: Swift.String
        var files: [Swift.String]
    }

    struct Member: Sendable {
        var path: Swift.String
        var repository: Swift.String
        var evaluation: Package.Manifest.Evaluation
        var targets: [Target]
    }

    /// One package's evaluation, or why it has none.
    enum Evaluated: Sendable {
        case member(Member)
        case failure(Swift.String)
    }
}

extension Institute.Inventory {
    /// Walks `configuration.root`, writes every table into
    /// `configuration.output`, and says what it found.
    public static func run(
        _ configuration: Configuration,
        progress: @escaping @Sendable (Swift.String) -> Void = { _ in }
    ) async throws(Institute.Error) -> Summary {
        let root = configuration.root
        let fanout = Async.Fanout(jobs: configuration.jobs)
        try Self.create(configuration.output)

        let discovery = Discovery(root: root, excluding: configuration.excluded)
        progress("found \(discovery.packages.count) packages in \(discovery.repositories.count) repositories")

        let repositories = await fanout.map(discovery.repositories) { path in
            Self.repository(path, root: root)
        }
        progress("read \(repositories.count) repositories")

        let scratch = configuration.output + "/.scratch"
        let total = discovery.packages.count
        let indexed = Swift.Array(discovery.packages.enumerated())
        let evaluated = await fanout.map(
            indexed,
            completed: { done in if done % 200 == 0 || done == total { progress("evaluated \(done)/\(total) manifests") } }
        ) { offset, path in
            Self.evaluate(
                path,
                root: root,
                repository: Self.enclosing(path, in: discovery.repositories),
                scratch: scratch + "/\(offset)"
            )
        }
        try? File.Directory(File.Path(scratch)).delete.recursive()

        var members: [Member] = []
        var failures: [(path: Swift.String, reason: Swift.String)] = []
        for (path, outcome) in zip(discovery.packages, evaluated) {
            switch outcome {
            case .member(let member): members.append(member)
            case .failure(let reason): failures.append((path, reason))
            }
        }
        for index in members.indices {
            for target in members[index].targets.indices { members[index].targets[target].package = index }
        }
        let packages = members
        let targets = members.flatMap(\.targets)

        let jobs = targets.enumerated().flatMap { offset, target in
            target.files.map { file in (target: offset, file: file) }
        }
        let fileCount = jobs.count
        let facts = await fanout.map(
            jobs,
            completed: { done in if done % 5000 == 0 || done == fileCount { progress("parsed \(done)/\(fileCount) files") } }
        ) { job -> Facts? in
            let target = targets[job.target]
            let package = packages[target.package].path
            let absolute = Self.absolute(package, root: root) + "/" + target.path + "/" + job.file
            return Discovery.text(at: absolute).map(Walker.facts(source:))
        }

        let assembly = Assembly(
            root: root,
            repositories: repositories,
            members: members,
            targets: targets,
            files: zip(jobs, facts).map { ($0.target, $0.file, $1) },
            failures: failures
        )
        let (tables, summary) = assembly.tables()
        for table in tables { try table.write(into: configuration.output) }
        return summary
    }

    static func create(_ directory: Swift.String) throws(Institute.Error) {
        do {
            try File.Directory(File.Path(directory)).create.recursive()
        } catch {
            throw .filesystem("cannot create \(directory): \(error)")
        }
    }

    static func absolute(_ relative: Swift.String, root: Swift.String) -> Swift.String {
        relative == "." ? root : root + "/" + relative
    }

    /// The nearest repository directory enclosing `path`.
    static func enclosing(_ path: Swift.String, in repositories: [Swift.String]) -> Swift.String {
        func depth(_ repository: Swift.String) -> Swift.Int { repository == "." ? 0 : repository.count }
        var best: Swift.String?
        for repository in repositories
        where repository == "." || path == repository || path.hasPrefix(repository + "/") {
            if best.map({ depth(repository) > depth($0) }) ?? true { best = repository }
        }
        return best ?? ""
    }

    static func repository(_ path: Swift.String, root: Swift.String) -> Repository {
        let git = Git.Client()
        guard let directory = try? File.Path(absolute(path, root: root)) else {
            return .init(path: path, origin: "", head: "", dirty: false)
        }
        let origin = (try? git.remote("origin", at: directory)).flatMap(Self.slug) ?? ""
        let head = (try? git.head(at: directory).rawValue) ?? ""
        let dirty = !((try? git.status(at: directory))?.isEmpty ?? true)
        return .init(path: path, origin: origin, head: head, dirty: dirty)
    }

    /// `owner/name` of a GitHub-style remote URL: `https://host/owner/name(.git)`,
    /// `git@host:owner/name(.git)` or `ssh://git@host/owner/name`.
    public static func slug(_ url: Swift.String) -> Swift.String? {
        var text = url.trimmingSuffix("/")
        if text.hasSuffix(".git") { text = Swift.String(text.dropLast(4)) }
        let separators: Swift.Set<Swift.Character> = ["/", ":"]
        let parts = text.split(whereSeparator: separators.contains).map(Swift.String.init)
        guard parts.count >= 3 else { return nil }
        return parts[parts.count - 2] + "/" + parts[parts.count - 1]
    }

    static func evaluate(
        _ path: Swift.String,
        root: Swift.String,
        repository: Swift.String,
        scratch: Swift.String
    ) -> Evaluated {
        let directory = absolute(path, root: root)
        let evaluation: Package.Manifest.Evaluation
        do throws(Package.Manager.Error) {
            let validated: File.Directory
            do throws(File.Path.Error) {
                validated = File.Directory(try File.Path(directory))
            } catch {
                return .failure("not a path: \(error)")
            }
            evaluation = try Package.Manager().evaluation(at: validated, timeout: .seconds(180), scratch: scratch)
        } catch {
            return .failure(Self.reason(error))
        }
        let targets = evaluation.targets.map { target in
            let name = target.name.underlying
            let relative = Self.sourceDirectory(target, package: directory)
            let files = relative.isEmpty ? [] : Discovery.swiftFiles(under: directory + "/" + relative)
            return Target(package: 0, manifest: target, name: name, path: relative, files: files)
        }
        return .member(.init(path: path, repository: repository, evaluation: evaluation, targets: targets))
    }

    /// The target's directory relative to the package: its `path:`, else
    /// the first of SwiftPM's conventional directories that exists.
    static func sourceDirectory(_ target: Package.Manifest.Target, package: Swift.String) -> Swift.String {
        if let path = target.path {
            var text = "\(path)"
            if text.hasPrefix("./") { text = Swift.String(text.dropFirst(2)) }
            if text.hasSuffix("/") { text = Swift.String(text.dropLast()) }
            return text.isEmpty ? "." : text
        }
        let name = target.name.underlying
        let parents: [Swift.String] =
            switch target.kind {
            case .test: ["Tests", "Sources", "Source", "src", "srcs"]
            case .plugin: ["Plugins"]
            case .binary: []
            default: ["Sources", "Source", "src", "srcs"]
            }
        for parent in parents where Discovery.isDirectory(package + "/" + parent + "/" + name) {
            return parent + "/" + name
        }
        return ""
    }

    static func reason(_ error: Package.Manager.Error) -> Swift.String {
        switch error {
        case .command(let termination, let stderr):
            let text = Swift.String(decoding: stderr, as: Swift.UTF8.self)
            let lines = text.split(separator: "\n").map { $0.trimmingCharacters() }.filter { !$0.isEmpty }
            let errors = lines.filter { $0.contains("error:") }
            let chosen = (errors.isEmpty ? Swift.Array(lines.suffix(3)) : Swift.Array(errors.prefix(3)))
                .joined(separator: " | ")
            let clipped = chosen.count > 600 ? Swift.String(chosen.prefix(600)) + "…" : chosen
            return "dump-package failed (\(termination)): \(clipped)"
        case .timedOut: return "dump-package timed out after 180 seconds"
        case .execution: return "could not start swift"
        case .output: return "dump-package wrote nothing"
        case .manifest: return "dump-package's output did not decode as a manifest evaluation"
        default: return "\(error)"
        }
    }
}

extension Swift.String {
    func trimmingSuffix(_ suffix: Swift.String) -> Swift.String {
        var text = self
        while text.hasSuffix(suffix) { text.removeLast(suffix.count) }
        return text
    }
}

extension Swift.Substring {
    func trimmingCharacters() -> Swift.String {
        var slice = self[...]
        while let first = slice.first, first.isWhitespace { slice.removeFirst() }
        while let last = slice.last, last.isWhitespace { slice.removeLast() }
        return Swift.String(slice)
    }
}
