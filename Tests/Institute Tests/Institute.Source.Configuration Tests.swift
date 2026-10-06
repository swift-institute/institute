import Institute_Model
import Institute_Source_Policy
import Institute_Source_Profile
import Source_Measurement
import Source_Profile
import Source_Repair
import Source_Report
import Testing

@testable import Institute_Source

private func renderedConfigurationPreparation(
    root: Swift.String
) throws -> Institute.Source.Preparation {
    let policy = Institute.Source.Policy.current
    try MainFixtureFiles.createDirectory(root)
    try MainFixtureFiles.write(
        bytes: Array(policy.swiftFormat.contents.utf8),
        to: MainFixtureFiles.join(root, policy.swiftFormat.path)
    )
    try MainFixtureFiles.write(
        bytes: Array(policy.swiftLint.contents.utf8),
        to: MainFixtureFiles.join(root, policy.swiftLint.path)
    )
    for bundle in policy.bundles {
        let artifact = policy.linter(
            bundle: bundle,
            rules: Institute.Source.Profile(policy: policy).rules(for: bundle)
        )
        try MainFixtureFiles.write(
            bytes: Array(artifact.contents.utf8),
            to: MainFixtureFiles.join(root, "\(bundle.token)-\(artifact.path)")
        )
    }
    return Institute.Source.Preparation(
        policyRevision: policy.revision,
        binding: .package(
            .init(identity: "swift-institute/swift-example@revision", digest: "subject-digest")
        ),
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        swiftLintExecutable: "/tools/swiftlint",
        swiftLint: .init(origin: .published(asset: "swiftlint"), digest: .init("swiftlint-tool")),
        linterExecutable: "/tools/swift-linter",
        linter: .init(
            origin: .published(asset: "swift-linter-macos-arm64"),
            digest: .init("linter-tool")
        ),
        directory: root,
        profiles: [:],
        verifiedProfiles: []
    )
}

private func measuredSourceSubject(identity: Swift.String) -> Source.Subject {
    .init(
        identity: identity,
        root: "/subjects/\(identity)",
        artifacts: [
            .init(
                path: "Sources/Example/Example.swift",
                kind: .swift,
                purpose: .governedSource,
                provenance: .authored,
                digest: .init("source-digest")
            )
        ]
    )
}

private func configurationReport(
    configuration: (subject: Source.Subject, evidence: [Source.Artifact.Evidence]),
    measured: [Source.Subject]
) -> Source_Report.Source.Report {
    let policy = Institute.Source.Policy.current
    let format = Source.Rule.ID(engine: .init("swift-format"), token: "format")
    let requirements: [Source_Report.Source.Report.Commitment.Requirement] = measured.map {
        .init(
            subject: $0.identity,
            engine: format.engine,
            artifacts: $0.paths(of: .swift),
            rules: [format]
        )
    }
    let measurements: [Source.Measurement] = measured.map { subject in
        let files = subject.paths(of: .swift).map { subject.root + "/" + $0 }.sorted()
        return .init(
            engine: format.engine,
            subject: subject,
            activeRules: [format],
            applicableRules: [format],
            files: files,
            observations: files.map {
                .init(file: $0, rule: format, applicable: true, coverage: .measured)
            },
            verdict: .clean
        )
    }
    let subjects = measured + [configuration.subject]
    let commitment = Source_Report.Source.Report.Commitment(
        subjects: subjects,
        engines: [
            .init(id: format.engine, artifactKinds: [.swift], controlPolicy: .transitionalExternal),
            .init(id: policy.configuration.engine, artifactKinds: [.configuration]),
        ],
        rules: [
            .init(id: format, controls: []),
            .init(id: policy.configuration.predicate, controls: []),
        ],
        requirements: requirements,
        predicates: [
            .init(id: policy.configuration.predicate, artifactKinds: [.configuration])
        ],
        predicateRequirements: [
            .init(
                subject: configuration.subject.identity,
                artifacts: configuration.subject.artifacts.map(\.path),
                predicates: [policy.configuration.predicate]
            )
        ]
    )
    return .init(
        scope: .workspace,
        profile: .init("profile-digest"),
        commitment: commitment,
        subjects: subjects,
        references: [],
        measurements: measurements,
        artifactEvidence: configuration.evidence,
        controlEvidence: []
    )
}

@Test
func `Generated source configuration is owned by the subject that carries it`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    let preparation = try renderedConfigurationPreparation(root: root)

    let configuration = try Institute.Source.Application.configuration(
        policy: .current,
        preparation: preparation
    )

    #expect(configuration.subject.identity == "control:source-profile")
    #expect(!configuration.subject.artifacts.isEmpty)
    for artifact in configuration.subject.artifacts {
        guard case .generated(let binding) = artifact.provenance else {
            Issue.record("expected generated provenance for \(artifact.path)")
            continue
        }
        #expect(binding.owner.identity == configuration.subject.identity)
    }
    #expect(configuration.evidence.allSatisfy { $0.subject == configuration.subject.identity })
}

@Test
func `Package scope source report with generated configuration is complete and clean`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    let preparation = try renderedConfigurationPreparation(root: root)
    let configuration = try Institute.Source.Application.configuration(
        policy: .current,
        preparation: preparation
    )

    let report = configurationReport(
        configuration: configuration,
        measured: [measuredSourceSubject(identity: "swift-institute/swift-example@revision")]
    )

    #expect(throws: Never.self) {
        try Source_Report.Source.Report.Complete(report, expected: report.commitment)
    }
    #expect(Source_Report.Source.Report.Status(report, expected: report.commitment) == .clean)
}

@Test
func `Workspace scope source report with a control row and generated configuration is complete and clean`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    let preparation = try renderedConfigurationPreparation(root: root)
    let configuration = try Institute.Source.Application.configuration(
        policy: .current,
        preparation: preparation
    )

    let report = configurationReport(
        configuration: configuration,
        measured: [
            measuredSourceSubject(identity: "swift-institute/swift-example"),
            measuredSourceSubject(identity: "control:continuous-integration"),
        ]
    )

    #expect(throws: Never.self) {
        try Source_Report.Source.Report.Complete(report, expected: report.commitment)
    }
    #expect(Source_Report.Source.Report.Status(report, expected: report.commitment) == .clean)
}

@Test
func `Source report whose generated configuration names an absent owner is unmeasured`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    let preparation = try renderedConfigurationPreparation(root: root)
    let configuration = try Institute.Source.Application.configuration(
        policy: .current,
        preparation: preparation
    )
    let orphaned = configuration.subject.artifacts.map { artifact -> Source.Artifact in
        guard case .generated(let binding) = artifact.provenance else { return artifact }
        return .init(
            path: artifact.path,
            kind: artifact.kind,
            purpose: artifact.purpose,
            provenance: .generated(
                .init(
                    owner: .init("control:absent-owner"),
                    input: binding.input,
                    revision: binding.revision,
                    digest: binding.digest
                )
            ),
            digest: artifact.digest
        )
    }
    let subject = Source.Subject(
        identity: configuration.subject.identity,
        root: configuration.subject.root,
        artifacts: orphaned
    )
    let evidence = configuration.evidence.map { evidence -> Source.Artifact.Evidence in
        .init(
            subject: evidence.subject,
            artifact: orphaned.first { $0.path == evidence.artifact.path } ?? evidence.artifact,
            predicate: evidence.predicate,
            actual: evidence.actual,
            expected: evidence.expected,
            verdict: evidence.verdict
        )
    }

    let report = configurationReport(
        configuration: (subject, evidence),
        measured: [measuredSourceSubject(identity: "swift-institute/swift-example@revision")]
    )

    #expect(throws: Source_Report.Source.Report.Complete.Error.self) {
        try Source_Report.Source.Report.Complete(report, expected: report.commitment)
    }
    #expect(Source_Report.Source.Report.Status(report, expected: report.commitment) == .unmeasured)
}
