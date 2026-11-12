public import Command
public import Command_Schema
import Console
import Diagnostic
import Environment
import File_System
import GitHub_Standard
import Git_Foundation
import Institute_CI_Model
public import Institute_Model
import Institute_Source
import Institute_Source_Policy
import Institute_Source_Workspace
import JSON
import Process
import Source_Measurement
import Source_Report
import Thread_Pool

extension Institute.Application {
    /// `institute lint` — the source lint of the package in the current
    /// directory, as `Quality · source` runs it, without being told what the
    /// package is.
    ///
    /// The repository is read from the `origin` remote and the revision from
    /// `HEAD`; the working tree is linted as it is, committed or not. The
    /// tools are the ones the source policy pins for this platform, fetched
    /// once into a directory shared between packages and checked against
    /// their digests on every run. With `--fix`, what `Source.Repair` can
    /// rewrite is rewritten first, and what is left is reported.
    public struct Lint: Sendable, Command_Schema::Command.`Protocol` {
        public var fix: Swift.Bool
        public var report: Swift.String

        public init(fix: Swift.Bool = false, report: Swift.String = "") {
            self.fix = fix
            self.report = report
        }
    }
}

extension Institute.Application.Lint {
    public static var configuration: Command_Schema::Command.Configuration {
        .init(
            name: "lint",
            abstract: "Lint the package in the current directory as Quality · source does.",
            discussion: """
                Run it in a package directory of a Git checkout. Each finding is one line: \
                location, severity, rule and message; errors come last, then every rule over \
                the repository's limit, then the outcome. The exit status is the one a strict \
                CI run would give: 0 when Quality · source would pass, 1 when it would fail \
                (an error, or a rule over its limit), 2 when the lint could not be completed. \
                --fix first rewrites what swift-format can repair (spacing, indentation, import \
                order). --report also writes the JSON report CI keeps as quality-report.
                """
        )
    }

    public static var schema: Command_Schema::Command.Schema.Definition<Self> {
        .init {
            Command_Schema::Command.Flag(
                \.fix,
                name: .long(.literal("fix")),
                help: .init(abstract: "Rewrite what Source Repair can before reporting.")
            )
            Command_Schema::Command.Option(
                \.report,
                name: .long(.literal("report")),
                placeholder: "file",
                help: .init(abstract: "Also write the JSON report to this file.")
            )
        }
    }

    public mutating func run() async throws(Institute.Error) {
        let code: Swift.Int32
        do throws(Institute.Error) {
            code = try await outcome()
        } catch {
            Console.Output.error("institute lint: \(error)\n")
            code = 2
        }
        Process.Exit.normal(code)
    }

    /// Lints the package in the current directory, prints the lines and
    /// returns the exit status.
    private func outcome() async throws(Institute.Error) -> Swift.Int32 {
        let root: File.Path
        do throws(File.System.Canonical.Error) {
            root = try File.System.Canonical.resolve(".")
        } catch {
            throw .filesystem("cannot resolve the current directory: \(error)")
        }
        guard File.Directory(root)[file: "Package.swift"].stat.isFile else {
            throw .configuration("run it in a package directory; \(root) has no Package.swift")
        }
        let git = Git.Client()
        let remote: Swift.String
        let revision: Swift.String
        let uncommitted: Swift.Bool
        do throws(Git.Client.Error) {
            remote = try git.remote("origin", at: root)
            revision = try git.head(at: root).rawValue
            uncommitted = try !git.status(at: root).isEmpty
        } catch {
            throw .repository("cannot read the Git checkout at \(root): \(error)")
        }
        guard let repository = Institute.Source.Workspace.repository(remote: remote) else {
            throw .repository("cannot tell the repository from origin's URL \(remote); expected …/owner/name")
        }
        let bundle = try Institute.Source.Application.bundle(
            Institute.Organization.lintBundle(forRepository: repository)
        )
        let identity = "\(repository)@\(revision)"
        let tools = Institute.Source.Application.tools(
            cache: Environment.read("XDG_CACHE_HOME"),
            home: Environment.read("HOME")
        )
        let application = Institute.Source.Application()
        var subject = try Institute.Source.Workspace.subject(identity: identity, root: "\(root)", using: git)
        var preparation = try await application.prepare(subject: subject, tools: tools)
        var lines: [Swift.String] = []
        if fix {
            let repaired = try await application.repair(subject: subject, bundle: bundle, preparation: preparation)
            lines += repaired.rewritten.map { "fixed: \($0)" }
            lines += repaired.declined.map { "not fixed: \($0.file): \($0.reason)" }
            if !repaired.rewritten.isEmpty {
                subject = try Institute.Source.Workspace.subject(identity: identity, root: "\(root)", using: git)
                preparation = try await application.prepare(subject: subject, tools: tools)
            }
        }
        let measured = try await application.measure(
            subject: subject,
            bundle: bundle,
            preparation: preparation
        )
        let bytes = measured.jsonString(sortKeys: true)
        let parsed: Source_Report::Source.Report
        do throws(JSON.Error) {
            parsed = try .init(jsonString: bytes)
        } catch {
            throw .configuration("source report serialization did not parse: \(error)")
        }
        if !report.isEmpty {
            let file: File
            do throws(File.Path.Error) {
                file = File(try File.Path(report))
            } catch {
                throw .configuration("--report \(report) is not a path: \(error)")
            }
            do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
                try await file.write.atomic(bytes + "\n")
            } catch {
                throw .filesystem("cannot write the report to \(report): \(error)")
            }
        }
        let overruns = Institute.CI.Command.Source.Ratchet.overruns(
            repository: "\(repository)",
            counts: Institute.CI.Command.Source.Ratchet.counts(parsed)
        )
        let code = Institute.CI.Command.Source.Policy.strict.code(
            status: Source_Report::Source.Report.Status(parsed, expected: parsed.commitment),
            errors: parsed.errors || !overruns.isEmpty
        )
        lines += Self.lines(
            parsed,
            root: "\(root)",
            overruns: overruns,
            subject: "\(repository)@\(revision.prefix(12))" + (uncommitted || fix ? ", working tree" : ""),
            exitCode: code
        )
        for line in lines { print(line) }
        return code
    }

    /// The lines `institute lint` prints for `report`: one per finding as
    /// `location: severity: [engine rule] message`, with paths relative to
    /// `root`, warnings and notes before errors so the errors end the list;
    /// then each rule over its limit; then the outcome.
    static func lines(
        _ report: Source_Report::Source.Report,
        root: Swift.String,
        overruns: [Swift.String],
        subject: Swift.String,
        exitCode: Swift.Int32
    ) -> [Swift.String] {
        let status = Source_Report::Source.Report.Status(report, expected: report.commitment)
        if case .unmeasured = status {
            return Institute.CI.Command.Source.summary(report, exitCode: exitCode, limit: .max)
                .map { $0.replacing("institute ci source:", with: "institute lint: \(subject):", maxReplacements: 1) }
        }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        func relative(_ path: Swift.String) -> Swift.String {
            path.hasPrefix(prefix) ? Swift.String(path.dropFirst(prefix.count)) : path
        }
        var findings: [(error: Swift.Bool, file: Swift.String, record: Diagnostic.Record, text: Swift.String)] = []
        var counts: (errors: Swift.Int, warnings: Swift.Int, notes: Swift.Int) = (0, 0, 0)
        for measurement in report.measurements {
            guard case .findings(let found) = measurement.verdict else { continue }
            for finding in found {
                let diagnostic = finding.diagnostic
                let file = relative(diagnostic.location.filePath ?? diagnostic.location.fileID)
                switch diagnostic.severity {
                case .error: counts.errors += 1
                case .warning: counts.warnings += 1
                default: counts.notes += 1
                }
                findings.append(
                    (
                        diagnostic.severity == .error,
                        file,
                        diagnostic,
                        "\(file):\(diagnostic.location.line):\(diagnostic.location.column): \(diagnostic.severity): "
                            + "[\(measurement.engine.token) \(finding.rule.token)] \(diagnostic.message)"
                    )
                )
            }
        }
        findings.sort { first, second in
            if first.error != second.error { return second.error }
            if first.file != second.file { return first.file < second.file }
            if first.record != second.record { return first.record < second.record }
            return first.text < second.text
        }
        var lines = findings.map(\.text)
        for evidence in report.artifactEvidence {
            guard case .findings(let reasons) = evidence.verdict else { continue }
            counts.errors += reasons.count
            lines += reasons.map { "\(evidence.artifact.path): error: [\(evidence.predicate.token)] \($0.code): \($0.detail)" }
        }
        for evidence in report.controlEvidence {
            guard case .findings(let reasons) = evidence.verdict else { continue }
            counts.errors += reasons.count
            lines += reasons.map { "control \(evidence.identity): error: \($0.code): \($0.detail)" }
        }
        lines += overruns
        let total = counts.errors + counts.warnings + counts.notes
        let outcome = exitCode == 0 ? "Quality · source would pass" : "Quality · source would fail"
        if total == 0 && overruns.isEmpty {
            lines.append("institute lint: \(subject): clean; \(outcome) (exit \(exitCode))")
        } else {
            lines.append(
                "institute lint: \(subject): \(counts.errors) errors, \(counts.warnings) warnings, \(counts.notes) notes, "
                    + "\(overruns.count) rules over their limit; \(outcome) (exit \(exitCode))"
            )
        }
        return lines
    }
}
