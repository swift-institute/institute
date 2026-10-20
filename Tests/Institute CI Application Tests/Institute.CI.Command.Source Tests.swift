import Command
import Institute_CI_Model
import Institute_Model
import Source_Report
import Testing

@testable import Institute_CI_Application

@Test
func `CI source parses one exact package subject`() throws {
    let command = try Command.parse(
        Institute.CI.Command.Source.self,
        from: [
            "--repository", "swift-standards/swift-iso-639",
            "--revision", String(repeating: "a", count: 40),
            "--root", "/work/swift-iso-639",
            "--bundle", "standards",
            "--xcode-application", "/Applications/Xcode_27.0.app",
            "--jobs", "3",
        ],
        initial: .init()
    )

    #expect(command.repository == "swift-standards/swift-iso-639")
    #expect(command.revision == String(repeating: "a", count: 40))
    #expect(command.root == "/work/swift-iso-639")
    #expect(command.bundle == "standards")
    #expect(command.xcodeApplication == "/Applications/Xcode_27.0.app")
    #expect(command.jobs == 3)
}

@Test(arguments: [
    [
        "--repository", "swift-standards/swift-iso-639",
        "--revision", "not-a-commit",
        "--root", "/work/swift-iso-639",
        "--bundle", "standards",
        "--xcode-application", "/Applications/Xcode_27.0.app",
    ],
    [
        "--repository", "swift-standards/swift-iso-639",
        "--revision", String(repeating: "a", count: 40),
        "--root", "/work/swift-iso-639",
        "--bundle", "standards",
        "--xcode-application", "/tmp/Xcode.app",
    ],
    [
        "--repository", "swift-standards/swift-iso-639",
        "--revision", String(repeating: "a", count: 40),
        "--root", "/work/swift-iso-639",
        "--bundle", "unknown",
        "--xcode-application", "/Applications/Xcode_27.0.app",
    ],
    [
        "--repository", "swift-standards/swift-iso-639",
        "--revision", String(repeating: "a", count: 40),
        "--root", "relative/swift-iso-639",
        "--bundle", "standards",
        "--xcode-application", "/Applications/Xcode_27.0.app",
    ],
])
func `CI source refuses inexact policy inputs`(_ arguments: [String]) {
    #expect(throws: Command.Error.self) {
        _ = try Command.parse(
            Institute.CI.Command.Source.self,
            from: arguments,
            initial: .init()
        )
    }
}

@Test
func `CI source exit policy defaults to advisory and parses strict`() throws {
    let base = [
        "--repository", "swift-standards/swift-iso-639",
        "--revision", String(repeating: "a", count: 40),
        "--root", "/work/swift-iso-639",
        "--bundle", "standards",
        "--xcode-application", "/Applications/Xcode_27.0.app",
    ]
    let advisory = try Command.parse(Institute.CI.Command.Source.self, from: base, initial: .init())
    let strict = try Command.parse(
        Institute.CI.Command.Source.self,
        from: base + ["--exit-policy", "strict"],
        initial: .init()
    )

    #expect(advisory.exitPolicy == "advisory")
    #expect(strict.exitPolicy == "strict")
    #expect(throws: Command.Error.self) {
        _ = try Command.parse(
            Institute.CI.Command.Source.self,
            from: base + ["--exit-policy", "lenient"],
            initial: .init()
        )
    }
}

@Test
func `CI source exit policy fails only strict runs with error findings`() {
    let advisory = Institute.CI.Command.Source.Policy.advisory
    let strict = Institute.CI.Command.Source.Policy.strict

    #expect(advisory.code(status: .clean, errors: false) == 0)
    #expect(advisory.code(status: .findings, errors: true) == 0)
    #expect(advisory.code(status: .unmeasured, errors: false) == 2)
    #expect(strict.code(status: .clean, errors: false) == 0)
    #expect(strict.code(status: .findings, errors: false) == 0)
    #expect(strict.code(status: .findings, errors: true) == 1)
    #expect(strict.code(status: .unmeasured, errors: true) == 2)
}

/// Real `Source.Report` values that `Source.Report.Complete` accepts: one
/// subject with one governed Swift file, one engine with one measured rule
/// and its transported control, and one artifact predicate on the same file.
/// Each case varies exactly one evidence channel; production `Status` and
/// `errors(in:)` classify it.
private enum PolicyReport {
    static let digest = String(repeating: "0", count: 64)
    static let engine = Source.Engine.ID("swift-format")
    static let rule = Source.Rule.ID(engine: engine, token: "AlwaysUseLowerCamelCase")
    static let predicate = Source.Rule.ID(engine: engine, token: "PolicyIdentity")
    static let root = "/work/swift-iso-639"
    static let path = "Sources/ISO639.swift"
    static let file = root + "/" + path
    static let control = "fixture-control"
    static let reason = Source.Reason(code: "fixture", detail: "fixture finding")
    static let artifact = Source.Artifact(
        path: path,
        kind: .swift,
        purpose: .governedSource,
        provenance: .authored,
        digest: .init(digest)
    )
    static let subject = Source.Subject(
        identity: "swift-standards/swift-iso-639",
        root: root,
        artifacts: [artifact]
    )
    static let identity = Source.Artifact.Identity(
        digest: .init(digest),
        schema: .init("swift-format")
    )
    static let commitment = Source.Report.Commitment(
        subjects: [subject],
        engines: [.init(id: engine, artifactKinds: [.swift])],
        rules: [.init(id: rule, controls: [control]), .init(id: predicate, controls: [])],
        requirements: [.init(subject: subject.identity, engine: engine, artifacts: [path], rules: [rule])],
        predicates: [.init(id: predicate, artifactKinds: [.swift])],
        predicateRequirements: [.init(subject: subject.identity, artifacts: [path], predicates: [predicate])]
    )

    static func finding(_ severity: Diagnostic.Severity, line: Int = 1) -> Source.Finding {
        .init(
            rule: rule,
            diagnostic: .init(
                location: .init(fileID: "ISO639.swift", filePath: file, line: line, column: 1),
                severity: severity,
                identifier: rule.token,
                message: "fixture finding"
            ),
            repair: .automatic
        )
    }

    static func report(
        findings: [Source.Finding] = [],
        artifactFinding: Bool = false,
        controlFinding: Bool = false,
        transportsControl: Bool = true,
        unmeasured: [Source.Reason]? = nil
    ) -> Source.Report {
        let controlEvidence = Source.Rule.Control.Evidence(
            identity: control,
            rule: rule,
            expectation: .clean,
            actualFindings: controlFinding ? 1 : 0,
            verdict: controlFinding ? .findings([reason]) : .clean
        )
        let controls = transportsControl ? [controlEvidence] : []
        return .init(
            scope: .workspace,
            profile: .init(digest),
            commitment: commitment,
            subjects: [subject],
            references: [],
            measurements: [
                .init(
                    engine: engine,
                    subject: subject,
                    activeRules: [rule],
                    applicableRules: [rule],
                    files: [file],
                    observations: [.init(file: file, rule: rule, applicable: true, coverage: .measured)],
                    repairs: findings.isEmpty ? [] : [.init(file: file, rule: rule, disposition: .unchanged)],
                    controls: controls,
                    verdict: unmeasured.map { .unmeasured($0) }
                        ?? (findings.isEmpty ? .clean : .findings(findings))
                )
            ],
            artifactEvidence: [
                .init(
                    subject: subject.identity,
                    artifact: artifact,
                    predicate: predicate,
                    actual: artifactFinding
                        ? .init(digest: .init(String(repeating: "1", count: 64)), schema: .init("swift-format"))
                        : identity,
                    expected: identity,
                    verdict: artifactFinding ? .findings([reason]) : .clean
                )
            ],
            controlEvidence: controls
        )
    }
}

@Test
func `CI source exit policy classifies complete real reports per evidence channel`() throws {
    typealias Policy = Institute.CI.Command.Source.Policy
    let cases: [(report: Source.Report, status: Source.Report.Status, strict: Int32)] = [
        (PolicyReport.report(), .clean, 0),
        (PolicyReport.report(findings: [PolicyReport.finding(.warning)]), .findings, 0),
        (PolicyReport.report(findings: [PolicyReport.finding(.error)]), .findings, 1),
        (PolicyReport.report(artifactFinding: true), .findings, 1),
        (PolicyReport.report(controlFinding: true), .findings, 1),
    ]

    for (report, expected, strict) in cases {
        _ = try Source.Report.Complete(report, expected: report.commitment)
        let status = Source.Report.Status(report, expected: report.commitment)
        let errors = report.errors

        #expect(status == expected)
        #expect(errors == (strict == 1))
        #expect(Policy.advisory.code(status: status, errors: errors) == 0)
        #expect(Policy.strict.code(status: status, errors: errors) == strict)
    }
}

/// The measurement-error report without its transported control evidence:
/// the committed `fixture-control` has no evidence row, so the report is
/// incomplete and both policies exit 2 despite the error finding.
@Test
func `CI source exit policy keeps an incomplete real report at two under both policies`() {
    typealias Policy = Institute.CI.Command.Source.Policy
    let report = PolicyReport.report(findings: [PolicyReport.finding(.error)], transportsControl: false)
    let status = Source.Report.Status(report, expected: report.commitment)

    #expect(throws: Source.Report.Complete.Error.self) {
        _ = try Source.Report.Complete(report, expected: report.commitment)
    }
    #expect(status == .unmeasured)
    #expect(report.errors)
    #expect(Policy.advisory.code(status: status, errors: report.errors) == 2)
    #expect(Policy.strict.code(status: status, errors: report.errors) == 2)
}

@Test
func `CI source summary names a clean report in one line`() {
    let lines = Institute.CI.Command.Source.summary(PolicyReport.report(), exitCode: 0)

    #expect(lines == ["institute ci source: clean (exit 0)"])
}

@Test
func `CI source summary lists each finding by location, rule and message`() {
    let report = PolicyReport.report(findings: [PolicyReport.finding(.error)])
    let lines = Institute.CI.Command.Source.summary(report, exitCode: 1)

    #expect(lines.first == "institute ci source: findings (exit 1)")
    #expect(lines.count == 2)
    #expect(lines[1] == PolicyReport.file + ":1:1: error: [swift-format AlwaysUseLowerCamelCase] fixture finding")
}

@Test
func `CI source summary keeps an incomplete report unmeasured with its reason`() {
    let report = PolicyReport.report(findings: [PolicyReport.finding(.error)], transportsControl: false)
    let lines = Institute.CI.Command.Source.summary(report, exitCode: 2)

    #expect(lines.first == "institute ci source: UNMEASURED, the report is incomplete (exit 2)")
    #expect(lines.contains { $0.hasPrefix("unmeasured: incomplete report: ") })
    #expect(!lines.contains { $0.contains("clean") })
}

@Test
func `CI source summary names an unmeasured engine and its reason`() {
    let report = PolicyReport.report(
        unmeasured: [Source.Reason(code: "malformed-output", detail: "Package.swift:83:23: expected value")]
    )
    let lines = Institute.CI.Command.Source.summary(report, exitCode: 2)

    #expect(lines.first?.contains("UNMEASURED") == true)
    #expect(lines.contains("unmeasured: swift-format: malformed-output: Package.swift:83:23: expected value"))
    #expect(!lines.contains { $0.contains("clean") })
}

@Test
func `CI source summary caps its findings and counts what it omitted`() {
    let report = PolicyReport.report(findings: [
        PolicyReport.finding(.error, line: 1),
        PolicyReport.finding(.warning, line: 2),
        PolicyReport.finding(.note, line: 3),
    ])
    let lines = Institute.CI.Command.Source.summary(report, exitCode: 1, limit: 1)

    #expect(lines.count == 3)
    #expect(lines.last == "2 more findings omitted; the JSON report on standard output has all 3")
}

@Test
func `CI source help documents the one command and its exit statuses`() {
    let error = #expect(throws: Command.Error.self) {
        _ = try Command.parse(Institute.CI.Command.Source.self, from: ["--help"], initial: .init())
    }
    if case .helpRequested? = error {
    } else {
        Issue.record("expected --help to request help, got \(String(describing: error))")
    }
    let usage = Institute.CI.Command.Source.usage

    #expect(usage.contains("institute ci -- source --repository <owner/name> --revision <commit>"))
    #expect(usage.contains("--exit-policy <advisory|strict>"))
    #expect(usage.contains("2 when the report is incomplete (unmeasured)"))
    #expect(usage.contains("Invalid arguments exit 64"))
    #expect(usage.contains("standard error"))
}
