public import Build_Coordinator
public import Environment
public import File_System
public import Institute_Development
public import Institute_Model
public import Process

extension Institute.Lint {
    /// `institute package check`: the local CI-parity gate.
    ///
    /// Runs, in this order, every gate hosted CI runs for one package —
    /// rendered central `swift-format`/SwiftLint configs,
    /// `swift-format lint --strict`, `swiftlint lint --strict`,
    /// swift-linter (unchanged, via
    /// ``Institute/Lint/measure(_:using:default:)``), a build, and a
    /// test — so a developer sees the same verdicts locally that hosted
    /// CI would report, before ever pushing.
    ///
    /// Every step runs even after an earlier one fails: a developer
    /// fixing several gates at once should see every verdict in one
    /// pass, not one push-and-wait cycle per gate. A step is never
    /// skipped to make a later one look better, and no step's result
    /// changes what a later step measures — the build and test steps
    /// run against the working tree exactly as `package build`/`package
    /// test` already do.
    ///
    /// ## Parity is explicit where it cannot be exact
    ///
    /// The swift-linter step reuses ``measure(_:using:default:)``
    /// unchanged, so it is byte-for-byte what `package lint` already
    /// runs — true parity, not an approximation. The `swift-format` and
    /// SwiftLint steps run the real local binaries against a vendored,
    /// checked-in copy of the central configs (``Profile``), because a
    /// lint run here never contacts the network (see
    /// institute-application/CLAUDE.md); that snapshot is refreshed by
    /// hand when `swift-institute/.github`'s root configs change, and is
    /// the one honest gap against true CI parity — CI always fetches the
    /// configs fresh at its own `job.workflow_sha`, this does not.
    public struct Check: Sendable {
        /// The resolved swift-linter installation this run measures with.
        public let lint: Institute.Lint

        public init(_ lint: Institute.Lint) {
            self.lint = lint
        }
    }
}

extension Institute.Lint.Check {
    /// One gate's outcome.
    ///
    /// Four states, not the three ``Measurement/Verdict`` uses: `check`
    /// adds a build/test outcome the underlying linter never has to
    /// represent. `unmeasured` still means what it means everywhere else
    /// in this capability — nothing was established, and it is never
    /// collapsed into `clean`.
    public enum Verdict: Swift.Equatable, Sendable {
        /// Rules ran over files and found nothing, or a build/test
        /// succeeded.
        case clean

        /// Rules ran over files and found something.
        case violations(count: Swift.Int, failing: Swift.Bool)

        /// A build or test invocation exited non-zero.
        case failed(exitCode: Swift.Int32)

        /// Nothing was established — a missing binary, an invocation that
        /// could not be adjudicated. Never reported as passing.
        case unmeasured(reason: Swift.String)

        /// Whether this verdict alone should fail the overall run.
        public var fails: Swift.Bool {
            switch self {
            case .clean: false
            case .violations(_, let failing): failing
            case .failed: true
            case .unmeasured: true
            }
        }

        public var isUnmeasured: Swift.Bool {
            if case .unmeasured = self { true } else { false }
        }

        public var text: Swift.String {
            switch self {
            case .clean: "clean"

            case .violations(let count, let failing):
                "\(count) violation\(count == 1 ? "" : "s")"
                    + "\(failing ? " (error severity)" : " (advisory)")"

            case .failed(let exitCode): "failed (exit \(exitCode))"

            case .unmeasured(let reason): "UNMEASURED — \(reason)"
            }
        }
    }

    /// One named step's verdict, in the order it ran.
    public struct Step: Swift.Equatable, Sendable {
        public let name: Swift.String
        public let verdict: Verdict
    }

    /// The whole run: every step, in order.
    public struct Report: Swift.Sendable {
        public var steps: [Step]

        /// Whether any step failed or could not be measured.
        public var fails: Swift.Bool {
            steps.contains { $0.verdict.fails }
        }
    }
}

extension Institute.Lint.Check.Report: Swift.CustomStringConvertible {
    public var description: Swift.String {
        steps.map { "\($0.name): \($0.verdict.text)" }.joined(separator: "\n")
    }
}

extension Institute.Lint.Check {
    /// Where the rendered central configs live for `package`.
    ///
    /// Ignored, package-local, scratch state under `.build` — re-rendered
    /// every run rather than trusted as a cache, so a stale copy can
    /// never be linted against by accident, and never committed, because
    /// it lives beside every other piece of SwiftPM-generated state a
    /// package's `.gitignore` already excludes.
    public func renderedConfigDirectory(for package: File.Directory) -> File.Directory {
        package[directory: ".build"][directory: "institute-check"]
    }

    /// Writes the vendored central configs (``Profile``) into `package`'s
    /// `.build`, unconditionally, every run.
    public func render(
        into package: File.Directory
    ) throws(Institute.Error) -> (swiftLint: File, swiftFormat: File) {
        let directory = renderedConfigDirectory(for: package)
        do throws(File.System.Create.Directory.Error) {
            try directory.create.recursive()
        } catch {
            throw .filesystem("cannot create \(directory): \(error)")
        }
        let swiftLintFile = directory[file: ".swiftlint.yml"]
        let swiftFormatFile = directory[file: ".swift-format"]
        do throws(File.System.Write.Atomic.Error) {
            try swiftLintFile.write.atomic(Institute.Lint.Profile.swiftLint)
        } catch {
            throw .filesystem("cannot render \(swiftLintFile): \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try swiftFormatFile.write.atomic(Institute.Lint.Profile.swiftFormat)
        } catch {
            throw .filesystem("cannot render \(swiftFormatFile): \(error)")
        }
        return (swiftLintFile, swiftFormatFile)
    }
}

extension Institute.Lint.Check {
    /// The Swift source files under `Sources/` and `Tests/`, matching the
    /// hosted `format` and `lint` jobs' own `find` invocation exactly:
    /// `find Sources Tests -name '*.swift'`, excluding any
    /// `*.docc/Resources/` directory at any depth, and excluding the
    /// top-level `Tests/Support/` and `Tests/Tutorial/` directories only
    /// — the same three exclusions `swift-ci.yml`'s `format` job
    /// documents.
    static func files(under package: File.Directory) throws(Institute.Error) -> [File] {
        var results: [File] = []
        for top: File.Path.Component in ["Sources", "Tests"] {
            let root = package[directory: top]
            guard root.stat.isDirectory else { continue }
            do throws(File.Directory.Walk.Error) {
                try root.walk.files { file in
                    let relative = Self.relativeComponents(file.path, to: package.path)
                    guard relative.last?.hasSuffix(".swift") == true else { return .continue }
                    guard !Self.isExcluded(relative) else { return .continue }
                    results.append(file)
                    return .continue
                }
            } catch {
                throw .filesystem("cannot enumerate \(root): \(error)")
            }
        }
        return results
    }

    private static func relativeComponents(
        _ path: File.Path,
        to base: File.Path
    ) -> [Swift.String] {
        let baseComponents = Array(base.components)
        let fullComponents = Array(path.components)
        guard
            fullComponents.count > baseComponents.count,
            fullComponents.prefix(baseComponents.count).elementsEqual(baseComponents)
        else {
            return fullComponents.map(\.string)
        }
        return fullComponents.dropFirst(baseComponents.count).map(\.string)
    }

    private static func isExcluded(_ relative: [Swift.String]) -> Swift.Bool {
        // `*/*.docc/Resources/*` — any depth.
        for index in 0..<max(0, relative.count - 1) {
            if relative[index].hasSuffix(".docc"), relative[index + 1] == "Resources" {
                return true
            }
        }
        // `Tests/Support/*` and `Tests/Tutorial/*` — top-level only.
        if relative.count >= 2, relative[0] == "Tests",
            relative[1] == "Support" || relative[1] == "Tutorial"
        {
            return true
        }
        return false
    }
}

extension Institute.Lint.Check {
    /// Resolves a developer tool from `PATH`.
    ///
    /// swift-format and SwiftLint are developer tooling, exactly like
    /// swift-linter and cclsp elsewhere in this capability: never
    /// installed or downloaded by Institute, and never a fixed machine
    /// path in durable configuration. A missing binary is reported as
    /// ``Verdict/unmeasured(reason:)`` with an actionable message, never
    /// auto-fetched.
    static func resolve(_ tool: Swift.String) -> File? {
        guard let path = Environment.read("PATH") else { return nil }
        #if os(Windows)
            let separator: Swift.Character = ";"
        #else
            let separator: Swift.Character = ":"
        #endif
        let component: File.Path.Component
        do throws(File.Path.Component.Error) {
            component = try File.Path.Component(Swift.String(tool))
        } catch {
            return nil
        }
        for directory in path.split(separator: separator, omittingEmptySubsequences: true) {
            let directoryPath: File.Path
            do throws(File.Path.Error) {
                directoryPath = try File.Path(Swift.String(directory))
            } catch {
                continue
            }
            let candidate = File.Directory(directoryPath)[file: component]
            if candidate.stat.isFile {
                return candidate
            }
        }
        return nil
    }
}

extension Institute.Lint.Check {
    /// Runs `swift-format lint --strict --ignore-unparsable-files` over
    /// `files`, argument for argument what `swift-ci.yml`'s `format` job
    /// runs, against the rendered central `.swift-format`.
    func swiftFormat(
        configuration: File,
        files: [File],
        at package: File.Directory
    ) -> Verdict {
        guard let executable = Self.resolve("swift-format") else {
            return .unmeasured(
                reason:
                    "swift-format is not on PATH; install it (e.g. the toolchain's bundled "
                    + "swift-format, or via Homebrew) — institute does not download it"
            )
        }
        guard !files.isEmpty else {
            return .unmeasured(reason: "no Swift files under Sources or Tests")
        }
        let arguments =
            [
                "lint", "--strict", "--ignore-unparsable-files", "--configuration",
                configuration.description,
            ]
            + files.map(\.description)
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable.description,
                    arguments: arguments,
                    environment: Environment.Snapshot.current().values,
                    stdout: .pipe,
                    stderr: .pipe,
                    workingDirectory: package.description
                )
            )
        } catch {
            return .unmeasured(reason: "cannot execute swift-format: \(error)")
        }
        switch output.status {
        case .exited(let code):
            let diagnostics =
                Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
                + Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
            let count = diagnostics.split(separator: "\n", omittingEmptySubsequences: true).count
            return code == 0 ? .clean : .violations(count: count, failing: true)

        case .signaled(let signal):
            return .unmeasured(reason: "swift-format terminated by signal \(signal)")

        case .stopped(let signal):
            return .unmeasured(reason: "swift-format stopped by signal \(signal)")
        }
    }

    /// Runs `swiftlint lint --strict` over `files`, argument for argument
    /// what `swift-ci.yml`'s `lint` job runs against a rootless explicit
    /// file list, against the rendered central `.swiftlint.yml`.
    func swiftLint(
        configuration: File,
        files: [File],
        at package: File.Directory
    ) -> Verdict {
        guard let executable = Self.resolve("swiftlint") else {
            return .unmeasured(
                reason:
                    "swiftlint is not on PATH; install it (e.g. via Homebrew or Mint) — "
                    + "institute does not download it"
            )
        }
        guard !files.isEmpty else {
            return .unmeasured(reason: "no Swift files under Sources or Tests")
        }
        let arguments =
            ["lint", "--strict", "--config", configuration.description] + files.map(\.description)
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable.description,
                    arguments: arguments,
                    environment: Environment.Snapshot.current().values,
                    stdout: .pipe,
                    stderr: .pipe,
                    workingDirectory: package.description
                )
            )
        } catch {
            return .unmeasured(reason: "cannot execute swiftlint: \(error)")
        }
        let standardOutput = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        switch output.status {
        case .exited(let code):
            guard
                standardOutput.contains("Done linting!") || standardOutput.contains("warning")
                    || standardOutput.contains("error")
            else {
                // SwiftLint prints a summary line only when it actually
                // scanned something; an empty explicit file list or a
                // resolution failure can still exit 0 having measured
                // nothing, and the same UNMEASURED-never-clean discipline
                // documented on `Institute.Lint.measure` applies here.
                return code == 0
                    ? .unmeasured(reason: "swiftlint reported no summary; nothing was measured")
                    : .unmeasured(
                        reason:
                            "swiftlint exited \(code) with no summary: "
                            + Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
                    )
            }
            let count = standardOutput.split(separator: "\n", omittingEmptySubsequences: true)
                .filter { $0.contains(": warning:") || $0.contains(": error:") }
                .count
            return code == 0 ? .clean : .violations(count: count, failing: true)

        case .signaled(let signal):
            return .unmeasured(reason: "swiftlint terminated by signal \(signal)")

        case .stopped(let signal):
            return .unmeasured(reason: "swiftlint stopped by signal \(signal)")
        }
    }
}

extension Institute.Lint.Check {
    /// Runs the whole gate for one package, in the order documented on
    /// ``Check``.
    ///
    /// - Parameters:
    ///   - target: The resolved package to check.
    ///   - jobs: Compile jobs handed to the build and test steps.
    ///   - fresh: Whether the build/test steps use fresh scratch state.
    public func run(
        _ target: Institute.Lint.Target,
        jobs: Swift.Int? = nil,
        fresh: Swift.Bool = false
    ) -> Report {
        var steps: [Step] = []

        let rendered: (swiftLint: File, swiftFormat: File)?
        do throws(Institute.Error) {
            rendered = try render(into: target.package)
        } catch {
            rendered = nil
            steps.append(
                .init(name: "render", verdict: .unmeasured(reason: "\(error)"))
            )
        }

        let sources: [File]
        do throws(Institute.Error) {
            sources = try Self.files(under: target.package)
        } catch {
            steps.append(
                .init(name: "swift-format", verdict: .unmeasured(reason: "\(error)"))
            )
            steps.append(
                .init(name: "swiftlint", verdict: .unmeasured(reason: "\(error)"))
            )
            return finish(steps, target: target, jobs: jobs, fresh: fresh)
        }

        if let rendered {
            steps.append(
                .init(
                    name: "swift-format",
                    verdict: swiftFormat(
                        configuration: rendered.swiftFormat,
                        files: sources,
                        at: target.package
                    )
                )
            )
            steps.append(
                .init(
                    name: "swiftlint",
                    verdict: swiftLint(
                        configuration: rendered.swiftLint,
                        files: sources,
                        at: target.package
                    )
                )
            )
        } else {
            steps.append(
                .init(
                    name: "swift-format",
                    verdict: .unmeasured(reason: "central configs failed to render")
                )
            )
            steps.append(
                .init(
                    name: "swiftlint",
                    verdict: .unmeasured(reason: "central configs failed to render")
                )
            )
        }

        return finish(steps, target: target, jobs: jobs, fresh: fresh)
    }

    private func finish(
        _ steps: [Step],
        target: Institute.Lint.Target,
        jobs: Swift.Int?,
        fresh: Swift.Bool
    ) -> Report {
        var steps = steps

        // The swift-linter step: unchanged, byte-for-byte what `package lint` runs.
        do throws(Institute.Error) {
            let installation = try lint.installation()
            let measurement = lint.measure(
                target,
                using: installation,
                default: Institute.Lint.Bundle.resolve(target.package, under: lint.hierarchy)
            )
            steps.append(.init(name: "swift-linter", verdict: verdict(for: measurement.verdict)))
        } catch {
            steps.append(.init(name: "swift-linter", verdict: .unmeasured(reason: "\(error)")))
        }

        let coordinator = Build.Coordinator(jobs: jobs)
        for (name, action) in [("build", Build.Action.build), ("test", Build.Action.test)] {
            do throws(Build.Error) {
                let status = try coordinator.run(
                    action,
                    at: target.package.description,
                    fresh: fresh
                )
                steps.append(
                    .init(name: name, verdict: status == 0 ? .clean : .failed(exitCode: status))
                )
            } catch {
                steps.append(.init(name: name, verdict: .unmeasured(reason: "\(error)")))
            }
        }

        return .init(steps: steps)
    }

    private func verdict(for measurement: Institute.Lint.Measurement.Verdict) -> Verdict {
        switch measurement {
        case .clean: .clean
        case .violations(let count, let failing): .violations(count: count, failing: failing)
        case .unmeasured(let reason): .unmeasured(reason: reason)
        }
    }
}
