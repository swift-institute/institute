import Institute_Model
import Source_Report
import Testing

@testable import Institute_Planner

extension Institute.Planner.Canary.Outcome {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Canary.Outcome.Test {
    /// A real `Source.Report` that `Source.Report.Complete` accepts — one
    /// subject, one governed file, one engine with one rule and its
    /// transported control, one artifact predicate — varied one evidence
    /// channel at a time. The shape mirrors the CI source tests' fixture.
    enum Report {
        static let digest = String(repeating: "0", count: 64)
        static let engine = Source.Engine.ID("swift-format")
        static let rule = Source.Rule.ID(engine: engine, token: "AlwaysUseLowerCamelCase")
        static let predicate = Source.Rule.ID(engine: engine, token: "PolicyIdentity")
        static let root = "/work/swift-addition"
        static let path = "Sources/Addition.swift"
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
        static let subject = Source.Subject(identity: "swift-atoms/swift-addition", root: root, artifacts: [artifact])
        static let identity = Source.Artifact.Identity(digest: .init(digest), schema: .init("swift-format"))
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
                    location: .init(fileID: "Addition.swift", filePath: file, line: line, column: 1),
                    severity: severity,
                    identifier: rule.token,
                    message: "fixture finding"
                ),
                repair: .automatic
            )
        }

        static func report(
            findings: [Source.Finding] = [],
            controlFinding: Bool = false,
            unmeasured: [Source.Reason]? = nil
        ) -> Source.Report {
            let controls = [
                Source.Rule.Control.Evidence(
                    identity: control,
                    rule: rule,
                    expectation: .clean,
                    actualFindings: controlFinding ? 1 : 0,
                    verdict: controlFinding ? .findings([reason]) : .clean
                )
            ]
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
                        actual: identity,
                        expected: identity,
                        verdict: .clean
                    )
                ],
                controlEvidence: controls
            )
        }

        /// The standard output of a `ci -- source` run reporting `report`.
        static func output(_ report: Source.Report) -> String {
            report.jsonString(sortKeys: true) + "\n"
        }
    }
}

extension Institute.Planner.Canary.Outcome.Test.Unit {

    @Test func `a clean report reads as clean with its control counted`() {
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 0, output: Institute.Planner.Canary.Outcome.Test.Report.output(Institute.Planner.Canary.Outcome.Test.Report.report())))
        #expect(outcome == .init(status: .clean, code: 0, controls: ["clean": 1]))
    }

    @Test func `error findings are counted per engine and rule and warnings are not`() {
        let report = Institute.Planner.Canary.Outcome.Test.Report.report(findings: [
            Institute.Planner.Canary.Outcome.Test.Report.finding(.error, line: 1),
            Institute.Planner.Canary.Outcome.Test.Report.finding(.error, line: 2),
            Institute.Planner.Canary.Outcome.Test.Report.finding(.warning, line: 3),
        ])
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 1, output: Institute.Planner.Canary.Outcome.Test.Report.output(report)))
        #expect(outcome.status == .findings)
        #expect(outcome.errors == ["swift-format AlwaysUseLowerCamelCase": 2])
    }

    @Test func `unmeasured reasons and control verdicts are read`() {
        let report = Institute.Planner.Canary.Outcome.Test.Report.report(
            controlFinding: true,
            unmeasured: [.init(code: "no-summary", detail: "the engine printed no summary")]
        )
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 2, output: "noise\n" + Institute.Planner.Canary.Outcome.Test.Report.output(report)))
        #expect(outcome.status == .unmeasured)
        #expect(outcome.unmeasured.contains("swift-format: no-summary: the engine printed no summary"))
        #expect(outcome.controls == ["findings": 1])
    }
}

extension Institute.Planner.Canary.Outcome.Test.`Edge Case` {

    @Test func `a run ended by a signal crashed`() {
        let outcome = Institute.Planner.Canary.Outcome(.init(code: nil, output: Institute.Planner.Canary.Outcome.Test.Report.output(Institute.Planner.Canary.Outcome.Test.Report.report())))
        #expect(outcome.status == .crashed)
    }

    @Test func `an exit outside the source exit contract crashed`() {
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 64, output: Institute.Planner.Canary.Outcome.Test.Report.output(Institute.Planner.Canary.Outcome.Test.Report.report())))
        #expect(outcome.status == .crashed)
    }

    @Test func `a run without a report line crashed`() {
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 2, output: "institute ci source: cannot prepare\n"))
        #expect(outcome == .init(status: .crashed, code: 2))
    }

    @Test func `an unreadable report crashed`() {
        let outcome = Institute.Planner.Canary.Outcome(.init(code: 0, output: "{\"artifactEvidence\": oops}\n"))
        #expect(outcome.status == .crashed)
    }
}
