import ASCII
import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import ContinuousIntegration
import Institute_CI_Canon

extension ContinuousIntegration.Validation {
    /// `[GH-IGNORE-001]` through `[GH-IGNORE-004]` — complete generated
    /// ignore policy, work preservation, deny-by-default shape, and tracked
    /// index coverage.
    ///
    /// **001** compares the complete root document and every declared nested
    /// test or benchmark package policy byte-for-byte. Handwritten tails,
    /// missing nested policy, undeclared nested policy, and broad recursive
    /// substitutes are divergent.
    ///
    /// **002 is the half that matters.** A whitelist inverts the failure
    /// mode. Before it, junk crept in and `git status` showed you; after
    /// it, anything not explicitly allowed is untracked and `git status`
    /// says *nothing* — on 2026-07-29 a research paper in this ecosystem
    /// existed only as an untracked directory, one `git clean` from being
    /// lost. A validator that asks only "is junk denied?" would have
    /// reported that repository clean. This one also asks "is real work
    /// still tracked?", which is what makes work-loss loud. Do not weaken
    /// it to a warning, and when a class whitelist gains a directory, add
    /// a probe for it here in the same change.
    ///
    /// **003** is shape: deny-by-default, proven behaviorally. A path no
    /// class admits must come back ignored; if it survives, the file is
    /// not a whitelist regardless of what its patterns look like. 001
    /// already implies this for a conformant file — 003 exists so a
    /// divergent or pre-canonical file is measured on its own shape, and
    /// so a canon edit that broke deny-by-default would fire the corpus
    /// before it shipped.
    ///
    /// **004** enumerates stage-0 records from the subject's real index and
    /// checks their pathnames against the repository-controlled hierarchy
    /// with `git check-ignore --no-index`. Both streams are NUL-delimited;
    /// symlinks and gitlinks are evaluated by pathname without dereferencing.
    /// Unmerged records, malformed output, ambient excludes, and Git failures
    /// refuse the environment rather than manufacturing a clean verdict.
    ///
    /// 002 and 003 evaluate the file **the way git will**: it is copied
    /// into a throwaway `git init` tree with the probe paths
    /// materialised, and `git check-ignore` decides. Reading the patterns
    /// and reasoning about them is how the premise of this gate came to
    /// be wrong in the first place — the absence of a `.swift-lint`
    /// deny-line was read as the absence of denial, when the whitelist
    /// was denying it all along.
    public struct Gitignore: Validator {
        public typealias Class = ContinuousIntegration.Canon.Gitignore.Class

        /// A path the whitelist is probed with, and whether git must be
        /// told it is a directory.
        ///
        /// The directory bit is carried because a pattern with a trailing
        /// slash — `**/.*/` — never matches a path git does not know to
        /// be one.
        public struct Probe: Sendable, Equatable {
            public let path: String
            public let isDirectory: Bool

            public init(_ path: String, isDirectory: Bool = false) {
                self.path = path
                self.isDirectory = isDirectory
            }
        }

        /// Paths every class must keep: the repository's own floor.
        public static let floor: [Probe] = [
            Probe("README.md"),
            Probe("LICENSE.md"),
            Probe(".github/workflows/ci.yml"),
            Probe(".gitignore"),
        ]

        /// Paths that carry package work. Every package-shaped class
        /// must keep all of them.
        public static let packageWork: [Probe] = [
            Probe("Sources/Core/Type.swift"),
            Probe("Sources/Core/Type.docc/Article.md"),
            Probe("Sources/Core/Type.docc/asset.png"),
            Probe("Tests/Core Tests/Type Tests.swift"),
            Probe("Tests/Core Tests/Fixtures/case.json"),
            Probe("Benchmarks/bench/main.swift"),
            Probe("Research/paper.md"),
            Probe("Experiments/probe/main.swift"),
            Probe("Package.swift"),
            Probe("Lint.swift"),
            Probe(".spi.yml"),
        ]

        /// Paths that carry real work for a class. Every one must
        /// survive that class's whitelist.
        public static func work(for class: Class) -> [Probe] {
            switch `class` {
            case .package:
                floor + packageWork

            case .scaffold:
                floor

            case .institute:
                floor + packageWork + [
                    Probe("canon/gitignore-package.txt"),
                    Probe("Policy/ruleset.json"),
                    Probe("Tools/tool/Package.swift"),
                    Probe("profile/README.md"),
                    Probe("RULINGS.md"),
                ]

            case .application:
                floor + packageWork + [
                    Probe("Public/favicon.ico"),
                    Probe("Resources/Views/page.html"),
                    Probe("Configuration/production.json"),
                    Probe(".env.example"),
                ]

            case .generator:
                floor + packageWork + [
                    Probe("Generation/main.swift")
                ]
            }
        }

        /// Paths that must be denied. Not a rule of its own — a positive
        /// control on the probe harness. If these come back tracked,
        /// `git check-ignore` is not being reached and every 002 pass in
        /// the run is vacuous, which is exactly the shape of green this
        /// ecosystem has been burned by.
        public static let junk: [Probe] = [
            Probe(".swift-lint/eval/Package.swift"),
            Probe("Sources/.swift-lint/manifest.json"),
            Probe(".build/debug/thing.o"),
        ]

        /// Paths no class admits. Each must come back ignored, or the
        /// file is not deny-by-default and `[GH-IGNORE-003]` fires. The
        /// spelling is deliberately unguessable so no class canon — nor
        /// any plausible local override — ever admits it.
        public static let unadmitted: [Probe] = [
            Probe("Unadmitted-GH-IGNORE-003/probe.txt"),
            Probe("unadmitted-gh-ignore-003.txt"),
        ]

        public let rules: [Rule] = [
            "GH-IGNORE-001", "GH-IGNORE-002", "GH-IGNORE-003", "GH-IGNORE-004",
        ]
        /// The package-class canon's path within the control-plane
        /// checkout. The other classes' documents are its siblings.
        public static let canonPath = "canon/gitignore-package.txt"

        /// Where the package-class canon lives. `nil` means *find it*:
        /// the working directory and each of its ancestors are searched
        /// for `canonPath`.
        ///
        /// The retired script resolved canon from its own location
        /// (`__file__/../../canon/…`), which a Swift executable cannot
        /// reproduce — a built binary is not in the checkout it validates,
        /// and under `swift test` it is not in one at all. Searching
        /// upward from the working directory answers the same question
        /// the same way for the harness, for `validate-gitignore.yml`, and
        /// for a developer running from anywhere inside the checkout.
        public let canon: String?

        public init(canon: String? = nil) {
            self.canon = canon
        }

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            // A root that is not there is not a repository of any class.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: subject.root, isDirectory: &isDirectory),
                isDirectory.boolValue
            else { return [] }
            try Self.validateRepositoryEnvironment(subject.root)

            let `class` = Class.of(
                repository: subject.repository,
                manifest: Self.read(subject.path("Package.swift"))
            )
            let path = canon ?? Self.resolvedCanonPath ?? Self.canonPath
            let classPath = Self.siblingCanonPath(of: path, for: `class`)
            guard let canonText = Self.read(classPath) else {
                throw .missingSupportFile(path: classPath)
            }
            do {
                _ = try ContinuousIntegration.Canon.Gitignore.Render(
                    canon: .init(canonText)
                )
            } catch {
                throw .missingSupportFile(path: classPath)
            }

            let conformance = rules[0]
            let workLoss = rules[1]
            let shape = rules[2]
            let indexedCoverage = rules[3]
            guard let text = Self.read(subject.path(".gitignore")) else {
                return [
                    Finding(
                        repository: subject.repository,
                        rule: conformance,
                        message: "no .gitignore; the canonical \(`class`.rawValue)-class "
                            + "whitelist is absent"
                    )
                ]
            }

            var findings: [Finding] = []
            switch ContinuousIntegration.Canon.Gitignore(text).isGenerated {
            case false:
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: conformance,
                        message: "no CANONICAL section; file predates the canonical whitelist"
                    )
                )

            case true where text != canonText:
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: conformance,
                        message: "complete generated policy diverges from \(`class`.canonPath) "
                            + "(class: \(`class`.rawValue)); handwritten tails are forbidden"
                    )
                )

            case true:
                break
            }

            let declaredNested = ContinuousIntegration.Canon.Gitignore.Nested.roots
                .filter { Self.read(subject.path("\($0)/Package.swift")) != nil }
            for root in ContinuousIntegration.Canon.Gitignore.Nested.roots {
                let nestedPath = subject.path("\(root)/.gitignore")
                let nestedText = Self.read(nestedPath)
                if declaredNested.contains(root) {
                    if nestedText != ContinuousIntegration.Canon.Gitignore.Nested.text {
                        findings.append(
                            Finding(
                                repository: subject.repository,
                                rule: conformance,
                                message:
                                    "declared nested package `\(root)/Package.swift` requires exact generated `\(root)/.gitignore` policy"
                            )
                        )
                    }
                } else if nestedText != nil {
                    findings.append(
                        Finding(
                            repository: subject.repository,
                            rule: conformance,
                            message: "undeclared nested policy `\(root)/.gitignore` is forbidden"
                        )
                    )
                }
            }
            let lawfulPolicyPaths = Set([".gitignore"] + declaredNested.map { "\($0)/.gitignore" })
            for policyPath in try Self.policyPaths(in: subject.root)
            where !lawfulPolicyPaths.contains(policyPath) {
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: conformance,
                        message:
                            "ignore policy `\(policyPath)` is not a declared generated policy location"
                    )
                )
            }

            // 002 and 003 evaluate the repository's ACTUAL file,
            // canonical or not — a divergent file that loses real work or
            // admits the unadmitted should say so on its own terms, not
            // only via 001.
            let work = Self.work(for: `class`)
            let ignored = try Self.ignored(
                under: text,
                probes: work + Self.junk + Self.unadmitted
            )
            for probe in work where ignored.contains(probe.path) {
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: workLoss,
                        message: "whitelist denies real work: `\(probe.path)` "
                            + "would be silently untracked"
                    )
                )
            }
            let tracked = Self.junk.filter { !ignored.contains($0.path) }
            if !tracked.isEmpty {
                // The control failed. Reported as a finding rather than
                // passed: a harness that cannot detect denial makes every
                // clean 002 above vacuous.
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: workLoss,
                        message: "probe control failed — tool state not denied ("
                            + tracked.map { "`\($0.path)`" }.joined(separator: ", ")
                            + "); this run's whitelist verdicts are not evidence"
                    )
                )
            }
            for probe in Self.unadmitted where !ignored.contains(probe.path) {
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: shape,
                        message: "not deny-by-default: unadmitted path `\(probe.path)` "
                            + "would be tracked"
                    )
                )
            }
            let indexed = try Self.indexedPaths(in: subject.root)
            let ignoredIndexed = try Self.ignoredIndexedPaths(indexed, in: subject.root)
            for path in ignoredIndexed {
                findings.append(
                    Finding(
                        repository: subject.repository,
                        rule: indexedCoverage,
                        message:
                            "tracked index path is ignored by generated repository policy: `\(path)`"
                    )
                )
            }
            return findings
        }
    }
}

extension ContinuousIntegration.Validation.Gitignore {
    /// `canonPath` found by walking up from the working directory, or
    /// `nil` when no ancestor carries it.
    static var resolvedCanonPath: String? {
        resolvedCanonPath(startingAt: FileManager.default.currentDirectoryPath)
            // The canon rides its owner: this package carries the
            // authoritative `canon/gitignore-package.txt` at its own
            // root, so a caller whose working directory is elsewhere —
            // a test runner, a consumer package — still resolves the
            // document this validator was built against.
            ?? resolvedCanonPath(
                startingAt: URL(filePath: #filePath).deletingLastPathComponent().path
            )
    }

    /// `canonPath` found by walking up from `directory`, or `nil` when
    /// no ancestor carries it.
    static func resolvedCanonPath(startingAt start: String) -> String? {
        var directory = URL(filePath: start, directoryHint: .isDirectory)
        while true {
            let candidate = directory.appending(path: canonPath).path
            if read(candidate) != nil { return candidate }
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { return nil }
            directory = parent
        }
    }

    /// The class-specific canon beside a resolved package-canon *file*.
    /// `canon` is a document path, not the `canon/` directory: take its
    /// parent once, then append the sibling document's filename. `URL`
    /// preserves the host platform's separator and root semantics; string
    /// concatenation produced mixed paths on Windows, and re-appending the
    /// class's relative `canon/...` path here would compose `canon/canon`.
    static func siblingCanonPath(of packageCanon: String, for `class`: Class) -> String {
        URL(filePath: packageCanon)
            .deletingLastPathComponent()
            .appending(path: "gitignore-\(`class`.rawValue).txt")
            .path
    }

    /// Retries `operation` briefly on Windows when it fails; runs it once
    /// everywhere else.
    ///
    /// GitHub's hosted Windows runners scan every newly created or
    /// freshly renamed file under `%TEMP%` before it settles — Windows
    /// Defender real-time protection and the Search Indexer both take a
    /// short-lived handle on it. `CreateDirectoryW`/`MoveFileExW` racing
    /// that scan fails with `ERROR_SHARING_VIOLATION` (Win32 code 32),
    /// which Foundation surfaces as `NSCocoaErrorDomain` 513 ("You
    /// don't have permission") with the Win32 code nested in
    /// `NSUnderlyingError` — a permission-shaped message for a lock
    /// that is not durable and clears within milliseconds. Under
    /// full-tier CI's heavier parallel file I/O this fires on every
    /// scratch-tree probe rather than intermittently, which is why it
    /// now reproduces consistently instead of flaking. Reading the
    /// scratch tree back with a bounded retry resolves the transient
    /// lock without weakening what the probe verifies: the same `git`
    /// still answers the same question once its inputs are actually on
    /// disk.
    ///
    /// The default budget was tuned against `Gitignore Tests.swift`,
    /// which calls `ignored(under:probes:)` a handful of times. `Corpus
    /// Tests.swift` calls the same function through the `Gitignore`
    /// validator once per corpus scenario — roughly a dozen `gh-ignore-*`
    /// scenarios, each probing the whitelist with the `work` + `junk` +
    /// `unadmitted` sets (order twenty probes), so a single run of
    /// `every owned scenario meets its expectation` drives on the order
    /// of two hundred scratch-tree mkdir/write pairs back to back with no
    /// idle time between them. That sustained churn keeps Defender's scan
    /// queue non-empty for materially longer than the brief, isolated
    /// contention the original budget (5 attempts, ≤0.5s total backoff)
    /// was sized for — the failure mode is identical
    /// (`ERROR_SHARING_VIOLATION`, ephemeral), just outlasting the
    /// window this call site had to clear it in. Widened rather than
    /// re-implemented: the fix is a larger budget for the same transient
    /// class, not a different mechanism.
    static func retryingTransientWindowsFailures<T>(
        attempts: Int = 10,
        _ operation: () throws -> T
    ) throws -> T {
        #if os(Windows)
            var lastError: Swift.Error!
            for attempt in 0..<attempts {
                do {
                    return try operation()
                } catch {
                    lastError = error
                    if attempt + 1 < attempts {
                        Thread.sleep(forTimeInterval: min(1.0, 0.05 * pow(2, Double(attempt))))
                    }
                }
            }
            throw lastError!
        #else
            return try operation()
        #endif
    }

    /// The text of a file, or `nil` when it is absent or is not a file.
    ///
    /// Normalized to LF. Every canon document and every subject
    /// `.gitignore` this validator reads is a Git-tracked blob pinned to
    /// LF; a Windows checkout of the *same* blob can materialize CRLF
    /// line endings on disk (`core.autocrlf`), which would otherwise
    /// make byte-for-byte comparisons against the in-memory canon (whose
    /// literals are LF) — and substring searches like `!/Lint/\n` —
    /// diverge on line-ending noise the source blob never had. Reading
    /// is the one place both this validator and its tests reach a
    /// canon/`.gitignore` file from, so normalizing here (rather than at
    /// each comparison site) closes the whole class at once.
    static func read(_ path: String) -> String? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            !isDirectory.boolValue,
            let data = FileManager.default.contents(atPath: path),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text.normalized(to: .lf)
    }

    /// Which probes the given `.gitignore` ignores, asked of git itself
    /// in a throwaway tree.
    ///
    /// - Throws: `EnvironmentDefect.missingSupportFile` when git cannot
    ///   be run or answers with neither of its two verdicts. The retired
    ///   script reported that as a `[GH-IGNORE-002]` *finding*, which
    ///   said a repository was defective when the machine was; under this
    ///   contract an unanswerable question is the exit-2 class. This is a
    ///   deliberate difference and it is unreachable on a working runner.
    static func ignored(
        under gitignore: String,
        probes: [Probe]
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> Set<String> {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ci-validation-gitignore-\(UUID().uuidString)")
        // `FileManager.removeItem(at:)` throws untyped, and a scratch
        // tree that outlives the probe is not a verdict about anything.
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                // Nothing depends on the scratch tree after this probe.
            }
        }

        for probe in probes {
            let target = root.appending(path: probe.path)
            let directory = probe.isDirectory ? target : target.deletingLastPathComponent()
            // `FileManager.createDirectory` throws untyped; its failure
            // here is exactly the defect raised in the catch. Retried
            // on Windows — see `retryingTransientWindowsFailures`.
            do {
                try Self.retryingTransientWindowsFailures {
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                }
            } catch {
                throw .unreadableSubject(root: root.path)
            }
            if !probe.isDirectory {
                FileManager.default.createFile(atPath: target.path, contents: Data())
            }
        }
        // LAST, and deliberately so: `.gitignore` is itself a probe —
        // the file must not ignore itself — and materialising probes
        // as empty files would otherwise truncate the very file under
        // test. Every verdict in the run would then reflect an empty
        // ignore file, so all junk reads as tracked and all work
        // reads as kept. The junk control caught exactly this.
        // `Data.write(to:options:)` throws untyped; its failure here is
        // exactly the defect raised in the catch.
        do {
            try Self.retryingTransientWindowsFailures {
                try Data(gitignore.utf8).write(
                    to: root.appending(path: ".gitignore"),
                    options: .atomic
                )
            }
        } catch {
            throw .unreadableSubject(root: root.path)
        }

        guard try git(["init", "-q", "."], in: root) == 0 else {
            throw .missingSupportFile(path: "git init")
        }
        var ignored: Set<String> = []
        for probe in probes {
            // 0 = ignored, 1 = not ignored, >1 = git itself failed.
            let status = try git(["check-ignore", "-q", "--", probe.path], in: root)
            guard status <= 1 else {
                throw .missingSupportFile(path: "git check-ignore \(probe.path)")
            }
            if status == 0 { ignored.insert(probe.path) }
        }
        return ignored
    }

    /// One `git` invocation in the throwaway tree, returning its status.
    private static func git(
        _ arguments: [String],
        in root: URL
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> Int32 {
        try git(arguments, in: root, input: nil).status
    }

    /// Stage-0 pathnames from the real index. Records of any other shape are
    /// refused rather than treated as an empty index.
    static func indexedPaths(
        in root: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> [String] {
        let result = try git(
            ["ls-files", "--stage", "-z"],
            in: URL(filePath: root),
            input: nil,
            environment: environment
        )
        guard result.status == 0 else { throw .unreadableSubject(root: root) }
        if result.output.isEmpty { return [] }
        var paths: [String] = []
        for record in result.output.split(separator: 0, omittingEmptySubsequences: false).dropLast()
        {
            guard let tab = record.firstIndex(of: 9) else { throw .unreadableSubject(root: root) }
            let header = record[..<tab].split(separator: 32)
            guard header.count == 3, header[2].elementsEqual([48]),
                let path = String(data: Data(record[record.index(after: tab)...]), encoding: .utf8),
                !path.isEmpty
            else { throw .unreadableSubject(root: root) }
            paths.append(path)
        }
        guard result.output.last == 0 else { throw .unreadableSubject(root: root) }
        return paths
    }

    /// Every effective per-directory policy input outside Git's own metadata.
    static func policyPaths(
        in root: String
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> [String] {
        let rootURL = URL(filePath: root)
        var directories: [(url: URL, relative: String)] = [(rootURL, "")]
        var paths: [String] = []
        while let directory = directories.popLast() {
            let contents: [URL]
            do {
                contents = try Self.retryingTransientWindowsFailures {
                    try FileManager.default.contentsOfDirectory(
                        at: directory.url,
                        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                    )
                }
            } catch {
                throw .unreadableSubject(root: root)
            }
            for url in contents {
                let relative =
                    directory.relative.isEmpty
                    ? url.lastPathComponent
                    : directory.relative + "/" + url.lastPathComponent
                if relative == ".git" { continue }
                if url.lastPathComponent == ".gitignore" { paths.append(relative) }
                let values: URLResourceValues
                do {
                    values = try Self.retryingTransientWindowsFailures {
                        try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    }
                } catch {
                    throw .unreadableSubject(root: root)
                }
                if values.isDirectory == true, values.isSymbolicLink != true {
                    directories.append((url, relative))
                }
            }
        }
        return Array(Set(paths)).sorted()
    }

    /// Tracked paths ignored by the repository-controlled hierarchy. The
    /// `--no-index` flag is load-bearing: without it Git suppresses exactly
    /// the force-added path this rule exists to detect.
    static func ignoredIndexedPaths(
        _ paths: [String],
        in root: String,
        noIndex: Bool = true
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> [String] {
        guard !paths.isEmpty else { return [] }
        try validateRepositoryEnvironment(root)

        var arguments = ["-c", "core.excludesFile=/dev/null", "check-ignore"]
        if noIndex { arguments.append("--no-index") }
        arguments += ["-z", "--stdin"]
        let input = paths.reduce(into: Data()) { data, path in
            data.append(contentsOf: path.utf8)
            data.append(0)
        }
        let result = try git(arguments, in: URL(filePath: root), input: input)
        guard result.status == 0 || result.status == 1,
            result.output.last == 0 || result.output.isEmpty
        else {
            throw .unreadableSubject(root: root)
        }
        var ignored: [String] = []
        for record in result.output.split(separator: 0) {
            guard let path = String(data: Data(record), encoding: .utf8), !path.isEmpty else {
                throw .unreadableSubject(root: root)
            }
            ignored.append(path)
        }
        return ignored
    }

    private static func validateRepositoryEnvironment(
        _ root: String
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) {
        let infoExclude = root + "/.git/info/exclude"
        if let contents = read(infoExclude),
            contents.split(whereSeparator: \.isNewline).contains(where: {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#")
            })
        {
            throw .unreadableSubject(root: root)
        }
    }

    /// Which half of a `git` invocation failed, kept distinct through the
    /// retry so the typed defect on the far side still matches what the
    /// caller saw before this function was made retryable: a missing
    /// executable is `missingSupportFile`, everything else touching the
    /// process transport is `unreadableSubject`.
    private enum GitInvocationFailure: Swift.Error {
        case processLaunch
        case transportIO
    }

    static func git(
        _ arguments: [String],
        in root: URL,
        input: Data?,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> (
        status: Int32, output: Data
    ) {
        guard let executable = gitExecutable(in: ProcessInfo.processInfo.environment) else {
            throw .missingSupportFile(path: "git")
        }
        // The full spawn-and-transport-I/O sequence is retried as one unit on
        // Windows — see `retryingTransientWindowsFailures`. `Process` and
        // its I/O handles are single-use, so a retry must rebuild them and rerun
        // `git` from scratch rather than resume a stuck pipe; every call
        // site invokes `git` idempotently (`init`, `check-ignore`,
        // `ls-files`), so rerunning it is safe.
        func invoke() throws(GitInvocationFailure) -> (status: Int32, output: Data) {
            let process = Process()
            let output = Pipe()
            process.executableURL = executable
            process.arguments = ["-C", root.path] + arguments
            // Git's ambient control variables can redirect the repository,
            // work tree, index, object database, configuration, and
            // namespace. A fixed environment removes that entire input
            // surface rather than trying to maintain a partial deny-list
            // of Git variables.
            process.environment = controlledGitEnvironment(environment, executable: executable)
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            // `git check-ignore --stdin` consumes a finite, already-materialized
            // path list. Give it a regular file rather than an asynchronously
            // written pipe: the child can never backpressure a producer while
            // this thread is draining stdout, so there is no bidirectional-pipe
            // deadlock and no dispatch work whose completion must be joined.
            let standardInput: FileHandle?
            let standardInputLocation: URL?
            if let input {
                let location = FileManager.default.temporaryDirectory
                    .appending(path: "institute-ci-git-stdin-\(UUID().uuidString)")
                // swift-linter:disable:next do throws for typed catch
                // REASON: Data.write and FileHandle.init expose untyped Foundation errors.
                do {
                    try input.write(to: location)
                    standardInput = try FileHandle(forReadingFrom: location)
                    standardInputLocation = location
                } catch {
                    // swift-linter:disable:next do throws for typed catch
                    // REASON: FileManager.removeItem exposes an untyped Foundation error.
                    do {
                        try FileManager.default.removeItem(at: location)
                    } catch {
                        // The original transport failure is authoritative.
                    }
                    throw GitInvocationFailure.transportIO
                }
            } else {
                standardInput = nil
                standardInputLocation = nil
            }
            defer {
                if let standardInput {
                    // swift-linter:disable:next do throws for typed catch
                    // REASON: FileHandle.close exposes an untyped Foundation error.
                    do {
                        try standardInput.close()
                    } catch {
                        // The process has already finished or been terminated.
                    }
                }
                if let standardInputLocation {
                    // swift-linter:disable:next do throws for typed catch
                    // REASON: FileManager.removeItem exposes an untyped Foundation error.
                    do {
                        try FileManager.default.removeItem(at: standardInputLocation)
                    } catch {
                        // Cleanup cannot change the invocation's observed result.
                    }
                }
            }
            process.standardInput = standardInput
            // `Process.run()` is an untyped cross-module throw; its only
            // durable failure here is "git is not on this machine", but on
            // Windows it can also surface the same transient
            // `ERROR_SHARING_VIOLATION` race the retry helper exists for
            // (spawning a process touches filesystem/kernel objects
            // Defender and the Search Indexer contend for), so it goes
            // through the same retry as the transport I/O below.
            do {
                try process.run()
            } catch {
                throw GitInvocationFailure.processLaunch
            }
            let data: Data
            do {
                data = try output.fileHandleForReading.readToEnd() ?? Data()
            } catch {
                process.terminate()
                process.waitUntilExit()
                throw GitInvocationFailure.transportIO
            }
            process.waitUntilExit()
            return (process.terminationStatus, data)
        }
        do {
            return try Self.retryingTransientWindowsFailures {
                try invoke()
            }
        } catch GitInvocationFailure.processLaunch {
            throw .missingSupportFile(path: "git")
        } catch {
            throw .unreadableSubject(root: root.path)
        }
    }

    static func gitExecutable(in environment: [String: String]) -> URL? {
        #if os(Windows)
            let separator: Character = ";"
            let names = ["git.exe"]
        #else
            let separator: Character = ":"
            let names = ["git"]
        #endif
        // Windows preserves the host spelling of environment keys. Its
        // standard `Path` spelling is semantically the same variable as
        // POSIX `PATH`, but `ProcessInfo.environment` presents it as a
        // case-sensitive Swift dictionary.
        guard
            let path = environment.first(where: {
                $0.key.caseInsensitiveCompare("PATH") == .orderedSame
            })?.value
        else { return nil }
        let fileManager = FileManager.default
        for rawDirectory in path.split(separator: separator, omittingEmptySubsequences: false) {
            let directory = rawDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !directory.isEmpty else { continue }
            for name in names {
                let candidate = URL(filePath: directory).appending(path: name)
                if fileManager.isExecutableFile(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    private static func controlledGitEnvironment(
        _ ambient: [String: String],
        executable: URL
    ) -> [String: String] {
        #if os(Windows)
            let null = "NUL"
        #else
            let null = "/dev/null"
        #endif
        var environment: [String: String] = [
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": null,
            "HOME": null,
            "LC_ALL": "C",
            "PATH": executable.deletingLastPathComponent().path,
            "XDG_CONFIG_HOME": null,
        ]
        #if os(Windows)
            // Git for Windows launches through its MSYS/Cygwin POSIX
            // emulation layer, which bootstraps from the Win32 environment
            // — including `SystemRoot` — to translate host paths (an 8.3
            // short-name ancestor such as the hosted runner's `RUNNER~1`
            // profile directory among them) into the form its runtime
            // operates on. A `CreateProcess` environment that omits these
            // is a documented way to break any Win32-hosted program's
            // startup, not a git-specific quirk: without them the process
            // can fail before it reaches the repository at all, which
            // surfaces here as the subject reading as unreadable rather
            // than as a git exit status. None of these carry the ambient
            // *git* control surface this isolation exists to remove
            // (repository, work tree, index, object database,
            // configuration, or namespace) — they are OS bootstrap
            // variables, not git variables — so restoring them narrows
            // nothing this function isolates.
            for name in [
                "SystemRoot", "SystemDrive", "windir", "ComSpec",
                "TEMP", "TMP", "USERPROFILE", "ALLUSERSPROFILE",
            ] {
                if let value = ambient.first(where: {
                    $0.key.caseInsensitiveCompare(name) == .orderedSame
                })?.value {
                    environment[name] = value
                }
            }
        #endif
        return environment
    }
}
