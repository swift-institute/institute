import Source_Measurement
import Source_Report
import Source_SwiftLint
import Source_Swift_Format
import Testing

private let repairCoverageRoot = "/subjects/example"

private func repairCoverageSubject() -> Source.Subject {
    .init(
        identity: "swift-institute/swift-example@revision",
        root: repairCoverageRoot,
        artifacts: ["Sources/A.swift", "Sources/B.swift"].map {
            .init(
                path: $0,
                kind: .swift,
                purpose: .governedSource,
                provenance: .authored,
                digest: .init("source-digest")
            )
        }
    )
}

private func repairCoverageReport(
    _ measurement: Source.Measurement,
    rules: [Source.Rule.ID]
) -> Source_Report::Source.Report {
    let subject = measurement.subject
    let commitment = Source_Report::Source.Report.Commitment(
        subjects: [subject],
        engines: [
            .init(id: measurement.engine, artifactKinds: [.swift], controlPolicy: .transitionalExternal)
        ],
        rules: rules.map { .init(id: $0, controls: []) },
        requirements: [
            .init(
                subject: subject.identity,
                engine: measurement.engine,
                artifacts: subject.paths(of: .swift),
                rules: rules
            )
        ],
        predicates: [],
        predicateRequirements: []
    )
    return .init(
        scope: .workspace,
        profile: .init("profile-digest"),
        commitment: commitment,
        subjects: [subject],
        references: [],
        measurements: [measurement],
        artifactEvidence: [],
        controlEvidence: []
    )
}

private func repairCoverageReplacing(
    _ measurement: Source.Measurement,
    repairs: [Source.Repair.Evidence]
) -> Source.Measurement {
    .init(
        engine: measurement.engine,
        subject: measurement.subject,
        activeRules: measurement.activeRules,
        applicableRules: measurement.applicableRules,
        files: measurement.files,
        observations: measurement.observations,
        suppressions: measurement.suppressions,
        repairs: repairs,
        controls: measurement.controls,
        verdict: measurement.verdict
    )
}

private let swiftFormatEngine = Source.Engine.ID("swift-format")
private let swiftFormatRules = [Source.Rule.ID(engine: swiftFormatEngine, token: "format")]

private func swiftFormatFindings() -> Source.Measurement {
    Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 1,
        output: "",
        diagnostics: [
            "\(repairCoverageRoot)/Sources/A.swift:3:1: error: [Indentation] indent by 4 spaces",
            "\(repairCoverageRoot)/Sources/A.swift:9:5: error: [LineLength] line is too long",
            "\(repairCoverageRoot)/Sources/B.swift:1:1: error: [OrderedImports] sort import statements",
        ].joined(separator: "\n")
    )
}

private let swiftLintEngine = Source.Engine.ID("swiftlint")
private let swiftLintRules = [
    Source.Rule.ID(engine: swiftLintEngine, token: "line_length"),
    Source.Rule.ID(engine: swiftLintEngine, token: "trailing_whitespace"),
]

private func swiftLintFinding(
    _ file: Swift::String,
    line: Swift::Int,
    rule: Swift::String
) -> Swift::String {
    """
    {"character":1,"file":"\(repairCoverageRoot)/\(file)","line":\(line),"reason":"reason","rule_id":"\(rule)","severity":"Error","type":"Type"}
    """
}

private func swiftLintFindings() -> Source.Measurement {
    Source.Measurement.swiftLint(
        engine: swiftLintEngine,
        subject: repairCoverageSubject(),
        rules: swiftLintRules,
        status: 2,
        output: "["
            + [
                swiftLintFinding("Sources/A.swift", line: 2, rule: "line_length"),
                swiftLintFinding("Sources/A.swift", line: 7, rule: "line_length"),
                swiftLintFinding("Sources/B.swift", line: 4, rule: "trailing_whitespace"),
            ].joined(separator: ",")
            + "]",
        diagnostics: ""
    )
}

private func isComplete(_ report: Source_Report::Source.Report) -> Swift::Bool {
    do throws(Source_Report::Source.Report.Complete.Error) {
        _ = try Source_Report::Source.Report.Complete(report, expected: report.commitment)
        return true
    } catch {
        return false
    }
}

@Test
func `Formatter findings carry one refused repair per file and rule and measure as findings`() {
    let measurement = swiftFormatFindings()

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected formatter findings")
        return
    }
    #expect(findings.count == 3)
    #expect(measurement.repairs.count == 2)
    #expect(
        measurement.repairs.allSatisfy {
            $0.disposition == .refused(.init(code: "repair-evidence-unavailable", detail: $0.file))
        }
    )
    let report = repairCoverageReport(measurement, rules: swiftFormatRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .findings)
}

@Test
func `SwiftLint findings carry one refused repair per file and rule and measure as findings`() {
    let measurement = swiftLintFindings()

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected SwiftLint findings, got \(measurement.verdict)")
        return
    }
    #expect(findings.count == 3)
    #expect(measurement.repairs.count == 2)
    #expect(
        measurement.repairs.allSatisfy {
            if case .refused(let reason) = $0.disposition {
                reason.code == "repair-evidence-unavailable"
            } else {
                false
            }
        }
    )
    let report = repairCoverageReport(measurement, rules: swiftLintRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .findings)
}

@Test
func `A finding without its refused repair keeps the report unmeasured`() {
    let measurement = swiftFormatFindings()
    let missing = repairCoverageReplacing(measurement, repairs: Swift::Array(measurement.repairs.dropFirst()))

    let report = repairCoverageReport(missing, rules: swiftFormatRules)

    #expect(!isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .unmeasured)
}

@Test
func `A duplicated refused repair keeps the report unmeasured`() {
    let measurement = swiftLintFindings()
    let duplicated = repairCoverageReplacing(
        measurement,
        repairs: measurement.repairs + [measurement.repairs[0]]
    )

    let report = repairCoverageReport(duplicated, rules: swiftLintRules)

    #expect(!isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .unmeasured)
}

@Test
func `A refused repair for a file outside the measurement keeps the report unmeasured`() {
    let measurement = swiftFormatFindings()
    let invalid = repairCoverageReplacing(
        measurement,
        repairs: measurement.repairs + [
            .init(
                file: "/elsewhere/C.swift",
                rule: swiftFormatRules[0],
                disposition: .refused(.init(code: "repair-evidence-unavailable", detail: "C"))
            )
        ]
    )

    let report = repairCoverageReport(invalid, rules: swiftFormatRules)

    #expect(!isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .unmeasured)
}

@Test
func `A clean formatter run carries no repairs and the report is clean`() {
    let measurement = Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 0,
        output: "",
        diagnostics: ""
    )

    guard case .clean = measurement.verdict else {
        Issue.record("expected a clean formatter verdict")
        return
    }
    #expect(measurement.repairs.isEmpty)
    let report = repairCoverageReport(measurement, rules: swiftFormatRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .clean)
}

@Test
func `A genuinely unmeasured formatter or SwiftLint run stays unmeasured`() {
    let formatter = Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 3,
        output: "",
        diagnostics: ""
    )
    let lint = Source.Measurement.swiftLint(
        engine: swiftLintEngine,
        subject: repairCoverageSubject(),
        rules: swiftLintRules,
        status: 2,
        output: "not json",
        diagnostics: ""
    )

    for (measurement, rules) in [(formatter, swiftFormatRules), (lint, swiftLintRules)] {
        guard case .unmeasured = measurement.verdict else {
            Issue.record("expected an unmeasured verdict for \(measurement.engine)")
            continue
        }
        #expect(measurement.repairs.isEmpty)
        let report = repairCoverageReport(measurement, rules: rules)
        #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .unmeasured)
    }
}

@Test
func `Source report status codes give findings a distinct exit from clean and unmeasured`() {
    #expect(Source_Report::Source.Report.Status.clean.code == 0)
    #expect(Source_Report::Source.Report.Status.findings.code == 1)
    #expect(Source_Report::Source.Report.Status.unmeasured.code == 2)
}

@Test
func `Identical repeated formatter diagnostics collapse to one finding and one refused repair`() {
    let repeated = "\(repairCoverageRoot)/Sources/A.swift:52:37: error: [DoNotUseSemicolons] remove ';'"
    let measurement = Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 1,
        output: "",
        diagnostics: [
            repeated,
            repeated,
            repeated,
            "\(repairCoverageRoot)/Sources/B.swift:1:1: error: [OrderedImports] sort import statements",
        ].joined(separator: "\n")
    )

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected formatter findings")
        return
    }
    #expect(findings.count == 2)
    #expect(measurement.repairs.count == 2)
    let report = repairCoverageReport(measurement, rules: swiftFormatRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .findings)
}

@Test
func `Distinct formatter diagnostics at one location are kept`() {
    let measurement = Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 1,
        output: "",
        diagnostics: [
            "\(repairCoverageRoot)/Sources/A.swift:52:37: error: [DoNotUseSemicolons] remove ';'",
            "\(repairCoverageRoot)/Sources/A.swift:52:37: error: [UseEarlyExits] replace this 'if/else' block",
            "\(repairCoverageRoot)/Sources/A.swift:52:37: error: [DoNotUseSemicolons] remove ';' and move the next statement",
        ].joined(separator: "\n")
    )

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected formatter findings")
        return
    }
    #expect(findings.count == 3)
    #expect(measurement.repairs.count == 1)
    let report = repairCoverageReport(measurement, rules: swiftFormatRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .findings)
}

private func swiftFormatMeasurement(_ diagnostics: [Swift::String]) -> Source.Measurement {
    Source.Measurement.swiftFormat(
        engine: swiftFormatEngine,
        subject: repairCoverageSubject(),
        rules: swiftFormatRules,
        status: 1,
        output: "",
        diagnostics: diagnostics.joined(separator: "\n")
    )
}

private func unmeasuredReasons(_ measurement: Source.Measurement) -> [Source.Reason]? {
    if case .unmeasured(let reasons) = measurement.verdict { reasons } else { nil }
}

@Test
func `A multi-line formatter diagnostic is one finding with its full quoted text`() {
    let measurement = swiftFormatMeasurement([
        "\(repairCoverageRoot)/Sources/A.swift:316:29: error: [NeverForceUnwrap] do not force unwrap 'Example(",
        "                    rawValue: value",
        "                )'",
        "\(repairCoverageRoot)/Sources/B.swift:1:1: error: [OrderedImports] sort import statements",
    ])

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected formatter findings, got \(measurement.verdict)")
        return
    }
    #expect(findings.count == 2)
    #expect(findings[0].diagnostic.identifier == "NeverForceUnwrap")
    #expect(findings[0].diagnostic.location.line == 316)
    #expect(
        findings[0].diagnostic.message
            == "do not force unwrap 'Example(\n                    rawValue: value\n                )'"
    )
    let report = repairCoverageReport(measurement, rules: swiftFormatRules)
    #expect(isComplete(report))
    #expect(Source_Report::Source.Report.Status(report, expected: report.commitment) == .findings)
}

@Test
func `A stray formatter line outside any quote stays unmeasured`() {
    let after = swiftFormatMeasurement([
        "\(repairCoverageRoot)/Sources/A.swift:3:1: error: [Indentation] indent by 4 spaces",
        "not a diagnostic",
    ])
    let first = swiftFormatMeasurement(["not a diagnostic"])

    #expect(unmeasuredReasons(after) == [.init(code: "malformed-output", detail: "not a diagnostic")])
    #expect(unmeasuredReasons(first) == [.init(code: "malformed-output", detail: "not a diagnostic")])
}

@Test
func `A quoted formatter diagnostic that never closes stays unmeasured`() {
    let measurement = swiftFormatMeasurement([
        "\(repairCoverageRoot)/Sources/A.swift:316:29: error: [NeverForceUnwrap] do not force unwrap 'Example(",
        "                    rawValue: value",
    ])

    #expect(unmeasuredReasons(measurement)?.map(\.code) == ["malformed-output"])
}

@Test
func `An apostrophe in a one-line formatter message does not absorb the next diagnostic`() {
    let measurement = swiftFormatMeasurement([
        "\(repairCoverageRoot)/Sources/A.swift:1:1: error: [ValidateDocumentationComments] don't document this",
        "\(repairCoverageRoot)/Sources/B.swift:1:1: error: [OrderedImports] sort import statements",
    ])

    guard case .findings(let findings) = measurement.verdict else {
        Issue.record("expected formatter findings, got \(measurement.verdict)")
        return
    }
    #expect(findings.map(\.diagnostic.identifier) == ["ValidateDocumentationComments", "OrderedImports"])
    #expect(findings[0].diagnostic.message == "don't document this")
}
