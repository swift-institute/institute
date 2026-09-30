public import Institute_Model
import struct Swift.String
import ASCII
import Byte
import Environment
import File_System
public import Institute_CI_Model
public import Institute_CI_Canon
import Process

#if os(Windows)
    import WinSDK
#endif

extension Institute.CI.Validation {
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
        public typealias Class = Institute.CI.Canon.Gitignore.Class

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
                    Probe("Institute.json"),
                    Probe("Peers.json"),
                    Probe("Selection.json"),
                    Probe("Context/AGENTS.md"),
                    Probe("institute control.xcworkspace/contents.xcworkspacedata"),
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
            Probe("institute control.xcworkspace/xcuserdata/user.xcuserdatad/state.plist"),
            Probe("institute control.xcworkspace/xcshareddata/swiftpm/Package.resolved"),
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
                        guard Institute.CI.Validation.isDirectory(subject.root)
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
                _ = try Institute.CI.Canon.Gitignore.Render(
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
            switch Institute.CI.Canon.Gitignore(text).isGenerated {
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

            let declaredNested = Institute.CI.Canon.Gitignore.Nested.roots
                .filter { Self.read(subject.path("\($0)/Package.swift")) != nil }
            for root in Institute.CI.Canon.Gitignore.Nested.roots {
                let nestedPath = subject.path("\(root)/.gitignore")
                let nestedText = Self.read(nestedPath)
                if declaredNested.contains(root) {
                    if nestedText != Institute.CI.Canon.Gitignore.Nested.text {
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

extension Institute.CI.Validation.Gitignore {
    /// `canonPath` found by walking up from the working directory, or
    /// `nil` when no ancestor carries it.
    static var resolvedCanonPath: String? {
        currentWorkingDirectory.flatMap { resolvedCanonPath(startingAt: $0) }
            // The canon rides its owner: this package carries the
            // authoritative `canon/gitignore-package.txt` at its own
            // root, so a caller whose working directory is elsewhere —
            // a test runner, a consumer package — still resolves the
            // document this validator was built against.
            ?? resolvedCanonPath(startingAt: String(#filePath).directoryPortion)
    }

    private static var currentWorkingDirectory: String? {
        guard let path = try? File.Path("."),
            let resolved = try? File.System.Canonical.resolve(path)
        else { return nil }
        return resolved.description
    }

    /// `canonPath` found by walking up from `directory`, or `nil` when
    /// no ancestor carries it.
    static func resolvedCanonPath(startingAt start: String) -> String? {
        guard var directory = try? File.Path(start) else { return nil }
        while true {
            guard let relative = try? File.Path(canonPath) else { return nil }
            let candidate = directory.appending(relative).description
            if read(candidate) != nil { return candidate }
            guard let parent = directory.parent else { return nil }
            guard parent.description != directory.description else { return nil }
            directory = parent
        }
    }

    /// The class-specific canon beside a resolved package-canon *file*.
    /// `canon` is a document path, not the `canon/` directory: take its
    /// parent once, then append the sibling document's filename.
    /// `File.Path` preserves the host platform's separator and root
    /// semantics; string concatenation produced mixed paths on Windows,
    /// and re-appending the class's relative `canon/...` path here would
    /// compose `canon/canon`.
    static func siblingCanonPath(of packageCanon: String, for `class`: Class) -> String {
        guard let path = try? File.Path(packageCanon), let parent = path.parent,
            let sibling = try? File.Path.Component("gitignore-\(`class`.rawValue).txt")
        else { return packageCanon.directoryPortion + "/gitignore-\(`class`.rawValue).txt" }
        return (parent / sibling).description
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
                        // Exponential backoff, capped at one second. The
                        // kernel sleep is reached through WinSDK directly:
                        // this branch is Windows-only bootstrap around a
                        // Defender/Search-Indexer scan race, and no
                        // Institute-owned substrate owns a synchronous
                        // sleep yet.
                        var milliseconds: UInt32 = 50
                        for _ in 0..<attempt where milliseconds < 1000 {
                            milliseconds *= 2
                        }
                        WinSDK.Sleep(min(milliseconds, 1000))
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
        guard Institute.CI.Validation.isFile(path),
            let text = Institute.CI.Validation.strictText(at: path)
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
    ) throws(Institute.CI.Validation.EnvironmentDefect) -> Set<String> {
        guard let root = scratchDirectory(prefix: "ci-validation-gitignore-") else {
            throw .missingSupportFile(path: "temporary directory")
        }
        // A scratch tree that outlives the probe is not a verdict about
        // anything; deletion failure changes nothing downstream.
        defer {
            if let path = try? File.Path(root) {
                try? File.System.Delete.delete(at: path, recursive: true)
            }
        }

        for probe in probes {
            let target = "\(root)/\(probe.path)"
            let directory = probe.isDirectory ? target : target.directoryPortion
            // Directory creation failure here is exactly the defect
            // raised in the catch. Retried on Windows — see
            // `retryingTransientWindowsFailures`.
            do {
                try Self.retryingTransientWindowsFailures {
                    let path = try File.Path(directory)
                    try File.System.Create.Directory.create(
                        at: path,
                        createIntermediates: true
                    )
                }
            } catch {
                throw .unreadableSubject(root: root)
            }
            if !probe.isDirectory {
                do {
                    try Self.retryingTransientWindowsFailures {
                        let path = try File.Path(target)
                        try File(path).write.atomic("")
                    }
                } catch {
                    throw .unreadableSubject(root: root)
                }
            }
        }
        // LAST, and deliberately so: `.gitignore` is itself a probe —
        // the file must not ignore itself — and materialising probes
        // as empty files would otherwise truncate the very file under
        // test. Every verdict in the run would then reflect an empty
        // ignore file, so all junk reads as tracked and all work
        // reads as kept. The junk control caught exactly this.
        do {
            try Self.retryingTransientWindowsFailures {
                let path = try File.Path("\(root)/.gitignore")
                try File(path).write.atomic(gitignore)
            }
        } catch {
            throw .unreadableSubject(root: root)
        }

        guard try git(["init", "-q", "."], in: root).status == 0 else {
            throw .missingSupportFile(path: "git init")
        }
        var ignored: Set<String> = []
        for probe in probes {
            // 0 = ignored, 1 = not ignored, >1 = git itself failed.
            let verdict = try git(["check-ignore", "-q", "--", probe.path], in: root).status
            guard verdict <= 1 else {
                throw .missingSupportFile(path: "git check-ignore \(probe.path)")
            }
            if verdict == 0 { ignored.insert(probe.path) }
        }
        return ignored
    }

    /// A fresh, unique scratch directory path under the platform
    /// temporary root, or `nil` when the platform declares none.
    private static func scratchDirectory(prefix: String) -> String? {
        #if os(Windows)
            let temporary = Environment.read("TEMP") ?? Environment.read("TMP") ?? "C:\\Temp"
        #else
            let temporary = Environment.read("TMPDIR") ?? "/tmp"
        #endif
        guard let anchorParent = try? File.Path(temporary),
            let anchorComponent = try? File.Path.Component("scratch"),
            let unique = try? File.Path.Temporary.sibling(
                of: anchorParent / anchorComponent,
                prefix: prefix
            )
        else { return nil }
        return unique.description
    }

    /// Stage-0 pathnames from the real index. Records of any other shape are
    /// refused rather than treated as an empty index.
    static func indexedPaths(
        in root: String,
        environment: [String: String] = Environment.Snapshot.current().values
    ) throws(Institute.CI.Validation.EnvironmentDefect) -> [String] {
        let result = try git(
            ["ls-files", "--stage", "-z"],
            in: root,
            environment: environment
        )
        guard result.status == 0 else { throw .unreadableSubject(root: root) }
        if result.output.isEmpty { return [] }
        var paths: [String] = []
        for record in result.output.split(separator: 0, omittingEmptySubsequences: false).dropLast()
        {
            guard let tab = record.firstIndex(of: 9) else { throw .unreadableSubject(root: root) }
            let header = record[..<tab].split(separator: 32)
            let path = Swift.String(
                decoding: record[record.index(after: tab)...],
                as: Swift.UTF8.self
            )
            guard header.count == 3, header[2].elementsEqual([48]), !path.isEmpty
            else { throw .unreadableSubject(root: root) }
            paths.append(path)
        }
        guard result.output.last == 0 else { throw .unreadableSubject(root: root) }
        return paths
    }

    /// Every effective per-directory policy input outside Git's own metadata.
    static func policyPaths(
        in root: String
    ) throws(Institute.CI.Validation.EnvironmentDefect) -> [String] {
        var directories: [(path: String, relative: String)] = [(root, "")]
        var paths: [String] = []
        while let directory = directories.popLast() {
            let entries: [(name: String, isDirectory: Bool)]
            do {
                entries = try Self.retryingTransientWindowsFailures {
                    let path = try File.Path(directory.path)
                    return try File.Directory.Contents.list(at: .init(path)).map { entry in
                        (Swift.String(lossy: entry.name), entry.type == .directory)
                    }
                }
            } catch {
                throw .unreadableSubject(root: root)
            }
            for entry in entries {
                let relative =
                    directory.relative.isEmpty
                    ? entry.name
                    : directory.relative + "/" + entry.name
                if relative == ".git" { continue }
                if entry.name == ".gitignore" { paths.append(relative) }
                // Symbolic links are evaluated by pathname without
                // dereferencing: the listing reports a link as a link,
                // never as the directory it points at, so a linked
                // subtree is not walked.
                if entry.isDirectory {
                    directories.append((directory.path + "/" + entry.name, relative))
                }
            }
        }
        return Array(Set(paths)).sorted()
    }

    /// Tracked paths ignored by the repository-controlled hierarchy. The
    /// `--no-index` flag is load-bearing: without it Git suppresses exactly
    /// the force-added path this rule exists to detect.
    ///
    /// The path list rides `check-ignore -z --stdin` so a pathname
    /// containing a space, a quote, or a newline is never re-encoded by
    /// Git's path quoting — `-z` is refused outside `--stdin`, and the
    /// non-`z` output re-quotes exactly the names this transport must
    /// carry byte-exactly. The capture seam cannot feed a stdin pipe, so
    /// on POSIX the NUL-delimited batch rides a private temporary file
    /// and `sh` performs only the redirection: every operand — the git
    /// executable, the repository, the batch file — passes positionally
    /// or through the environment, never through shell text. Windows has
    /// no such redirector in this seam and probes per path with `-q`,
    /// where the exit status alone is the verdict and no output is
    /// parsed at all.
    static func ignoredIndexedPaths(
        _ paths: [String],
        in root: String,
        noIndex: Bool = true
    ) throws(Institute.CI.Validation.EnvironmentDefect) -> [String] {
        guard !paths.isEmpty else { return [] }
        try validateRepositoryEnvironment(root)

        #if os(Windows)
            var ignored: [String] = []
            for path in paths {
                var arguments = ["-c", "core.excludesFile=/dev/null", "check-ignore", "-q"]
                if noIndex { arguments.append("--no-index") }
                arguments += ["--", path]
                let result = try git(arguments, in: root)
                if result.status == 0 {
                    ignored.append(path)
                } else if result.status != 1 {
                    throw .unreadableSubject(root: root)
                }
            }
            return ignored
        #else
            let executable: String
            do throws(Process.Error) {
                executable = try Process.Spawn.Executable.resolve(gitName)
            } catch {
                throw .missingSupportFile(path: "git")
            }
            var batch: [Byte] = []
            for path in paths {
                batch.append(contentsOf: [Byte](utf8: path))
                batch.append(Byte(0))
            }
            let batchFile: File.Path
            do {
                let anchor = try File.Path.Temporary.deterministic(
                    prefix: "institute-check-ignore",
                    key: "",
                    suffix: ""
                )
                let staged = try File.Path.Temporary.sibling(
                    of: anchor,
                    prefix: "institute-check-ignore-",
                    suffix: ".z"
                )
                try File(staged).write.atomic(contentsOf: batch)
                batchFile = staged
            } catch {
                throw .unreadableSubject(root: root)
            }
            defer {
                // swift-linter:disable:next try optional
                // REASON: cleanup of a private temporary file; a failed
                // delete leaves only tmpdir residue and must not mask the
                // check's own outcome.
                try? File.System.Delete.delete(at: batchFile)
            }

            var arguments = [
                executable, "-C", root, "-c", "core.excludesFile=/dev/null", "check-ignore",
            ]
            if noIndex { arguments.append("--no-index") }
            arguments += ["-z", "--stdin"]
            var environment = controlledGitEnvironment(
                Environment.Snapshot.current().values,
                executable: executable
            )
            environment["INSTITUTE_CHECK_IGNORE_BATCH"] = batchFile.description
            let output: Process.Output
            do {
                output = try Self.retryingTransientWindowsFailures {
                    try Process.Spawn.run(
                        .init(
                            executable: "/bin/sh",
                            arguments: ["-c", #"exec "$0" "$@" < "$INSTITUTE_CHECK_IGNORE_BATCH""#]
                                + arguments,
                            environment: environment,
                            stdin: .inherit,
                            stdout: .pipe,
                            stderr: .pipe
                        )
                    )
                }
            } catch {
                throw .unreadableSubject(root: root)
            }
            guard case .exited(let code) = output.status, code == 0 || code == 1 else {
                throw .unreadableSubject(root: root)
            }
            let bytes = output.stdout ?? []
            guard bytes.last == 0 || bytes.isEmpty else {
                throw .unreadableSubject(root: root)
            }
            var ignored: [String] = []
            for record in bytes.split(separator: 0) {
                let path = Swift.String(decoding: record, as: Swift.UTF8.self)
                guard !path.isEmpty else { throw .unreadableSubject(root: root) }
                ignored.append(path)
            }
            return ignored
        #endif
    }

    private static func validateRepositoryEnvironment(
        _ root: String
    ) throws(Institute.CI.Validation.EnvironmentDefect) {
        let infoExclude = root + "/.git/info/exclude"
        if let contents = read(infoExclude),
            contents.split(whereSeparator: \.isNewline).contains(where: {
                !$0.trimmedWhitespace.isEmpty && !$0.hasPrefix("#")
            })
        {
            throw .unreadableSubject(root: root)
        }
    }

    static func git(
        _ arguments: [String],
        in root: String,
        environment: [String: String] = Environment.Snapshot.current().values
    ) throws(Institute.CI.Validation.EnvironmentDefect) -> (
        status: Int32, output: [UInt8]
    ) {
        let executable: String
        do throws(Process.Error) {
            executable = try Process.Spawn.Executable.resolve(gitName)
        } catch {
            throw .missingSupportFile(path: "git")
        }
        // The spawn is retried as one unit on Windows — see
        // `retryingTransientWindowsFailures`. Every call site invokes
        // `git` idempotently (`init`, `check-ignore`, `ls-files`), so
        // rerunning it is safe.
        do {
            let output = try Self.retryingTransientWindowsFailures {
                try Process.Spawn.run(
                    .init(
                        executable: executable,
                        arguments: ["-C", root] + arguments,
                        // Git's ambient control variables can redirect the
                        // repository, work tree, index, object database,
                        // configuration, and namespace. A fixed environment
                        // removes that entire input surface rather than
                        // trying to maintain a partial deny-list of Git
                        // variables.
                        environment: controlledGitEnvironment(environment, executable: executable),
                        // The seam feeds no stdin and none of the invoked
                        // subcommands (`init`, `check-ignore` without
                        // `--stdin`, `ls-files`) read it; the capture runner
                        // supports no stdin pipe, so the stream is inherited.
                        stdin: .inherit,
                        stdout: .pipe,
                        stderr: .pipe
                    )
                )
            }
            guard case .exited(let code) = output.status else {
                throw Institute.CI.Validation.EnvironmentDefect.unreadableSubject(root: root)
            }
            return (code, output.stdout ?? [])
        } catch let defect as Institute.CI.Validation.EnvironmentDefect {
            throw defect
        } catch {
            throw .unreadableSubject(root: root)
        }
    }

    private static var gitName: String {
        #if os(Windows)
            "git.exe"
        #else
            "git"
        #endif
    }

    private static func controlledGitEnvironment(
        _ ambient: [String: String],
        executable: String
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
            "PATH": executable.directoryPortion,
            "XDG_CONFIG_HOME": null,
        ]
        #if os(Windows)
            // Git for Windows launches through its MSYS/Cygwin POSIX
            // emulation layer, which bootstraps from the Win32 environment
            // — including `SystemRoot` — to translate host paths into the
            // form its runtime operates on. A child environment that omits
            // these is a documented way to break any Win32-hosted
            // program's startup, not a git-specific quirk. None of these
            // carry the ambient *git* control surface this isolation
            // exists to remove — they are OS bootstrap variables, not git
            // variables — so restoring them narrows nothing this function
            // isolates.
            for name in [
                "SystemRoot", "SystemDrive", "windir", "ComSpec",
                "TEMP", "TMP", "USERPROFILE", "ALLUSERSPROFILE",
            ] {
                if let value = ambient.first(where: {
                    $0.key.lowercased() == name.lowercased()
                })?.value {
                    environment[name] = value
                }
            }
        #endif
        return environment
    }
}
