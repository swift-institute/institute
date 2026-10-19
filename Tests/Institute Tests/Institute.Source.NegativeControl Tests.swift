import Institute_Model
import Institute_Source_Policy
import Institute_Source_Workspace
import Source_Execution
import Source_Measurement
import Testing

private let compound =
    "Tests/Institute CI Validation Tests/Fixtures/test-009/fail/swift-compound-names/Tests/Foo Primitives Tests/FooBufferTests.swift"
private let dotted =
    "Tests/Institute CI Validation Tests/Fixtures/test-009/fail/swift-dot-before-tests/Tests/Foo Primitives Tests/Foo.Buffer.Tests.swift"
private let linter = Source.Engine.ID("swift-linter")
private let suffix = Source.Rule.ID(engine: linter, token: "test file suffix")

private func fixtureRoot(_ paths: [Swift.String]) throws -> Swift.String {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    for path in ["Package.swift", "Sources/Owned.swift"] + paths {
        let file = MainFixtureFiles.join(root, path)
        try MainFixtureFiles.createDirectory(Swift.String(file[..<file.lastIndex(of: "/")!]))
        let contents = path == "Package.swift" ? "// swift-tools-version: 6.4\nimport PackageDescription\n" : "enum Fixture {}\n"
        try MainFixtureFiles.write(bytes: Array(contents.utf8), to: file)
    }
    return root
}

@Test
func `declared negative controls leave governed source and become controls of their rule`() throws {
    let root = try fixtureRoot([compound, dotted])
    defer { try? MainFixtureFiles.remove(root) }
    let subject = try Institute.Source.Workspace.subject(
        identity: "swift-institute/institute@0123456789abcdef0123456789abcdef01234567",
        root: root,
        paths: ["Package.swift", "Sources/Owned.swift", compound, dotted]
    )

    #expect(subject.governed.paths(of: .swift) == ["Package.swift", "Sources/Owned.swift"])
    let controls = subject.artifacts.compactMap { artifact -> Source.Artifact.Purpose.Control? in
        guard case .control(let control) = artifact.purpose else { return nil }
        return control
    }
    #expect(
        controls == [
            .init(identity: "swift-institute/institute:\(compound)", predicate: suffix, expectation: .findings(1)),
            .init(identity: "swift-institute/institute:\(dotted)", predicate: suffix, expectation: .findings(1)),
        ]
    )
}

@Test
func `workspace control identities resolve to their repository's negative controls`() throws {
    let root = try fixtureRoot([compound, dotted])
    defer { try? MainFixtureFiles.remove(root) }
    let subject = try Institute.Source.Workspace.subject(
        identity: "control:institute",
        root: root,
        paths: ["Package.swift", "Sources/Owned.swift", compound, dotted]
    )
    #expect(subject.governed.paths(of: .swift) == ["Package.swift", "Sources/Owned.swift"])
}

@Test
func `a declared negative control that is no longer a source artifact is a configuration error`() throws {
    let root = try fixtureRoot([compound])
    defer { try? MainFixtureFiles.remove(root) }
    #expect(throws: Institute.Error.self) {
        try Institute.Source.Workspace.subject(
            identity: "swift-institute/institute",
            root: root,
            paths: ["Package.swift", "Sources/Owned.swift", compound]
        )
    }
}

@Test
func `a repository without declared negative controls keeps them as governed source`() throws {
    let root = try fixtureRoot([compound])
    defer { try? MainFixtureFiles.remove(root) }
    let subject = try Institute.Source.Workspace.subject(
        identity: "swift-compositions/swift-example",
        root: root,
        paths: ["Package.swift", "Sources/Owned.swift", compound]
    )
    #expect(subject.governed == subject)
}

/// A driver that reports one `test file suffix` finding per file whose name
/// lacks " Tests.swift", the way the real rule does for these fixtures, and
/// records which files it was asked to measure.
private func driver(
    findingsPerFile: Swift.Int,
    measured: Measured
) -> Source.Engine.Driver {
    .init(
        id: linter,
        measure: { subject, engine in
            let files = subject.paths(of: .swift).map { subject.root + "/" + $0 }
            await measured.append(files)
            let findings = files.filter { $0.contains("/Fixtures/") }.flatMap { file in
                Array(
                    repeating: Source.Finding(
                        rule: suffix,
                        diagnostic: .init(
                            location: .init(fileID: file, filePath: file, line: 5, column: 1),
                            severity: .error,
                            identifier: "test file suffix",
                            message: "fixture"
                        ),
                        repair: .unavailable(.init(code: "fixture", detail: file))
                    ),
                    count: findingsPerFile
                )
            }
            return .init(
                engine: linter,
                subject: subject,
                activeRules: engine.rules,
                applicableRules: [],
                files: files,
                verdict: findings.isEmpty ? .clean : .findings(findings)
            )
        },
        repair: { _, _ in .init(edits: [], refusals: []) }
    )
}

private actor Measured {
    var runs: [[Swift.String]] = []
    func append(_ files: [Swift.String]) { runs.append(files) }
}

private func measure(findingsPerFile: Swift.Int) async throws -> (Source.Measurement, [[Swift.String]]) {
    let artifact = { (path: Swift.String, purpose: Source.Artifact.Purpose) in
        Source.Artifact(path: path, kind: .swift, purpose: purpose, provenance: .authored, digest: .init("00"))
    }
    let control = Source.Artifact.Purpose.Control(identity: "fixture", predicate: suffix, expectation: .findings(1))
    let subject = Source.Subject(
        identity: "swift-example/swift-example",
        root: "/repo",
        artifacts: [artifact("Sources/Owned.swift", .governedSource), artifact(compound, .control(control))]
    )
    let measured = Measured()
    let execution = try Source.Execution(drivers: [driver(findingsPerFile: findingsPerFile, measured: measured)])
    let profile = Source.Profile(
        revision: "test",
        engines: [
            .init(
                id: linter,
                executable: "/bin/false",
                tool: .init("00"),
                configuration: .init("00"),
                configurationPath: "/dev/null",
                artifactKinds: [.swift],
                rules: [suffix]
            )
        ]
    )
    let measurements = await execution.measure(subject, profile: profile)
    return (try #require(measurements.first), await measured.runs)
}

@Test
func `a negative control that trips its rule as declared is clean evidence, and its finding is not a Quality finding`() async throws {
    let (measurement, runs) = try await measure(findingsPerFile: 1)
    // One run over the whole tree, as swift-linter requires; the split is on the result.
    #expect(runs == [["/repo/Sources/Owned.swift", "/repo/\(compound)"]])
    #expect(measurement.files == ["/repo/Sources/Owned.swift"])
    guard case .clean = measurement.verdict else {
        Issue.record("governed source must not carry the control's finding")
        return
    }
    let evidence = try #require(measurement.controls.first)
    #expect(evidence.identity == "fixture")
    #expect(evidence.actualFindings == 1)
    guard case .clean = evidence.verdict else {
        Issue.record("a control that trips as declared is clean evidence")
        return
    }
}

@Test(arguments: [0, 2])
func `a negative control that stops tripping its rule, or trips it differently, fails`(
    _ findings: Swift.Int
) async throws {
    let (measurement, _) = try await measure(findingsPerFile: findings)
    let evidence = try #require(measurement.controls.first)
    #expect(evidence.actualFindings == findings)
    guard case .findings(let reasons) = evidence.verdict else {
        Issue.record("a control that does not trip as declared must fail")
        return
    }
    #expect(reasons.map(\.code) == ["control-failed"])
}
