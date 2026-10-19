public import Command
public import Command_Schema
import Console
public import Institute_CI_Model
public import Institute_Model
public import Institute_Source
import Institute_Source_Policy
public import Institute_Source_Workspace
public import JSON
import Process
public import Source_Report

extension Institute.CI.Command {
    public struct Source: Sendable, Command_Schema.Command.`Protocol` {
        public var repository: Swift.String
        public var revision: Swift.String
        public var root: Swift.String
        public var bundle: Swift.String
        public var xcodeApplication: Swift.String
        public var jobs: Swift.Int?
        public var exitPolicy: Swift.String

        public init(
            repository: Swift.String = "",
            revision: Swift.String = "",
            root: Swift.String = "",
            bundle: Swift.String = "",
            xcodeApplication: Swift.String = "",
            jobs: Swift.Int? = nil,
            exitPolicy: Swift.String = Policy.advisory.rawValue
        ) {
            self.repository = repository
            self.revision = revision
            self.root = root
            self.bundle = bundle
            self.xcodeApplication = xcodeApplication
            self.jobs = jobs
            self.exitPolicy = exitPolicy
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "source", abstract: "Measure one checked-out package source subject.")
        }

        static let usage = """
            Measure one checked-out package:

              institute ci -- source --repository <owner/name> --revision <commit>
                --root <package-root> --bundle <primitives|standards|institute>
                --xcode-application </Applications/Xcode.app>
                [--jobs <positive-count>] [--exit-policy <advisory|strict>]

            --revision is an exact lowercase 40-character commit, --root an
            absolute path, and --xcode-application an application under
            /Applications. --exit-policy defaults to advisory.

            The JSON report goes to standard output. A bounded summary goes to
            standard error: the outcome, every reason a report is unmeasured, and
            each finding as location, severity, rule and message.

            Once the report is produced, the exit policy decides the status:
              advisory  0 when the report is complete, with or without findings.
              strict    0 when the report is complete with no error-severity
                        finding and no artifact or control finding; 1 otherwise.
              both      2 when the report is incomplete (unmeasured).
            Invalid arguments exit 64 before measurement; other failures exit 2.
            """

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.repository,
                    name: .long(.literal("repository")),
                    placeholder: "owner/name"
                )
                Command_Schema.Command.Option(
                    \.revision,
                    name: .long(.literal("revision")),
                    placeholder: "commit"
                )
                Command_Schema.Command.Option(
                    \.root,
                    name: .long(.literal("root")),
                    placeholder: "package-root"
                )
                Command_Schema.Command.Option(
                    \.bundle,
                    name: .long(.literal("bundle")),
                    placeholder: "primitives|standards|institute"
                )
                Command_Schema.Command.Option(
                    \.xcodeApplication,
                    name: .long(.literal("xcode-application")),
                    placeholder: "/Applications/Xcode.app"
                )
                Command_Schema.Command.Option(
                    \.jobs,
                    name: .long(.literal("jobs")),
                    placeholder: "positive-count"
                )
                Command_Schema.Command.Option(
                    \.exitPolicy,
                    name: .long(.literal("exit-policy")),
                    placeholder: "advisory|strict"
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            let repositoryComponents = repository.split(
                separator: "/",
                omittingEmptySubsequences: false
            )
            guard repositoryComponents.count == 2,
                repositoryComponents.allSatisfy({ !$0.isEmpty })
            else {
                throw .validationFailed(reason: "--repository must be owner/name")
            }
            guard revision.utf8.count == 40,
                revision.utf8.allSatisfy({
                    ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
                })
            else {
                throw .validationFailed(
                    reason: "--revision must be an exact lowercase 40-character commit"
                )
            }
            guard root.hasPrefix("/") else {
                throw .validationFailed(reason: "--root must be an absolute package path")
            }
            guard Institute.Source.Bundle(rawValue: bundle) != nil else {
                throw .validationFailed(
                    reason: "--bundle must be primitives, standards, or institute"
                )
            }
            guard xcodeApplication.hasPrefix("/Applications/"),
                xcodeApplication.hasSuffix(".app")
            else {
                throw .validationFailed(
                    reason: "--xcode-application must name an application under /Applications"
                )
            }
            guard jobs.map({ $0 > 0 }) ?? true else {
                throw .validationFailed(reason: "--jobs must be positive")
            }
            guard Policy(rawValue: exitPolicy) != nil else {
                throw .validationFailed(reason: "--exit-policy must be advisory or strict")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let bundle = try Institute.Source.Application.bundle(bundle)
            let subject = try Institute.Source.Workspace.subject(
                repository: repository,
                revision: revision,
                root: root
            )
            let application = Institute.Source.Application()
            let preparation = try await application.prepare(
                subject: subject,
                xcodeApplication: xcodeApplication
            )
            let measured = try await application.measure(
                subject: subject,
                bundle: bundle,
                jobs: jobs,
                preparation: preparation
            )
            let bytes = measured.jsonString(sortKeys: true)
            let report: Source_Report.Source.Report
            do throws(JSON.Error) {
                report = try .init(jsonString: bytes)
            } catch {
                throw .configuration("source report serialization did not parse: \(error)")
            }
            let code = (Policy(rawValue: exitPolicy) ?? .advisory).code(
                status: Source_Report.Source.Report.Status(report, expected: report.commitment),
                errors: Policy.errors(in: report)
            )
            print(bytes)
            for line in Self.summary(report, exitCode: code) {
                Console.Output.error(line + "\n")
            }
            Process.Exit.normal(code)
        }
    }

    static func source(_ arguments: [Swift.String]) async {
        var command: Source
        do throws(Command_Schema.Command.Error) {
            command = try Command_Schema.Command.parse(
                Source.self,
                from: arguments,
                initial: .init()
            )
        } catch {
            if case .helpRequested = error {
                print(Source.usage)
                terminate(0)
            }
            Console.Output.error("institute ci source: \(error)\n")
            terminate(64)
        }
        do throws(Institute.Error) {
            try await command.run()
        } catch {
            Console.Output.error("institute ci source: \(error)\n")
            terminate(2)
        }
    }
}

extension Institute.CI.Command.Source {
    static func summary(
        _ report: Source_Report::Source.Report,
        exitCode: Swift::Int32,
        limit: Swift::Int = 50
    ) -> [Swift::String] {
        var lines: [Swift::String] = []
        switch Source_Report::Source.Report.Status(report, expected: report.commitment) {
        case .clean:
            lines.append("institute ci source: clean (exit \(exitCode))")

        case .findings:
            lines.append("institute ci source: findings (exit \(exitCode))")

        case .unmeasured:
            lines.append("institute ci source: UNMEASURED, the report is incomplete (exit \(exitCode))")
            do throws(Source_Report::Source.Report.Complete.Error) {
                _ = try Source_Report::Source.Report.Complete(report, expected: report.commitment)
            } catch {
                lines.append("unmeasured: incomplete report: \(error)")
            }
            for measurement in report.measurements {
                guard case .unmeasured(let reasons) = measurement.verdict else { continue }
                for reason in reasons {
                    lines.append("unmeasured: \(measurement.engine.token): \(reason.code): \(reason.detail)")
                }
            }
            for evidence in report.artifactEvidence {
                guard case .unmeasured(let reasons) = evidence.verdict else { continue }
                for reason in reasons {
                    lines.append("unmeasured: \(evidence.artifact.path): \(reason.code): \(reason.detail)")
                }
            }
            for evidence in report.controlEvidence {
                guard case .unmeasured(let reasons) = evidence.verdict else { continue }
                for reason in reasons {
                    lines.append("unmeasured: control \(evidence.identity): \(reason.code): \(reason.detail)")
                }
            }
        }

        var findings: [Swift::String] = []
        for measurement in report.measurements {
            guard case .findings(let found) = measurement.verdict else { continue }
            for finding in found {
                let diagnostic = finding.diagnostic
                let location = diagnostic.location
                findings.append(
                    "\(location.filePath ?? location.fileID):\(location.line):\(location.column): "
                        + "\(diagnostic.severity): [\(measurement.engine.token) \(finding.rule.token)] "
                        + diagnostic.message
                )
            }
        }
        for evidence in report.artifactEvidence {
            guard case .findings(let reasons) = evidence.verdict else { continue }
            for reason in reasons {
                findings.append(
                    "\(evidence.artifact.path): [\(evidence.predicate.token)] \(reason.code): \(reason.detail)"
                )
            }
        }
        for evidence in report.controlEvidence {
            guard case .findings(let reasons) = evidence.verdict else { continue }
            for reason in reasons {
                findings.append("control \(evidence.identity): \(reason.code): \(reason.detail)")
            }
        }

        lines.append(contentsOf: findings.prefix(limit))
        if findings.count > limit {
            lines.append(
                "\(findings.count - limit) more findings omitted; the JSON report on standard output has all \(findings.count)"
            )
        }
        return lines
    }
}
