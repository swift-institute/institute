import Institute_CI_Model
import Institute_Model
import Source_Report
import Testing

@testable import Institute_Command

@Suite struct `Source ratchet` {
    typealias Ratchet = Institute.CI.Command.Source.Ratchet

    static let table = """
        swift-atoms/swift-a|comment in source|2
        swift-atoms/swift-a|raw value access|1
        swift-atoms/swift-b|comment in source|9
        """

    @Test func `counts at or under a limit pass`() {
        #expect(
            Ratchet.overruns(
                repository: "swift-atoms/swift-a",
                counts: ["comment in source": 2],
                table: Self.table
            ).isEmpty
        )
    }

    @Test func `a count over its limit names the rule, and another repository's limit doesn't help`() {
        let overruns = Ratchet.overruns(
            repository: "swift-atoms/swift-a",
            counts: ["comment in source": 3, "raw value access": 1],
            table: Self.table
        )
        #expect(overruns.count == 1)
        #expect(overruns.first?.contains("3 `comment in source` findings, limit 2") == true)
    }

    @Test func `a listed repository may have none of a rule not listed`() {
        #expect(Ratchet.overruns(repository: "swift-atoms/swift-a", counts: ["new rule": 1], table: Self.table).count == 1)
    }

    @Test func `a repository not listed has no limits until its first measurement`() {
        #expect(Ratchet.overruns(repository: "swift-atoms/swift-new", counts: ["comment in source": 1], table: Self.table).isEmpty)
    }

    @Test func `a strict run fails on an overrun and an advisory one doesn't`() {
        let strict = Institute.CI.Command.Source.Policy.strict
        let advisory = Institute.CI.Command.Source.Policy.advisory
        #expect(strict.code(status: .findings, errors: true) != 0)
        #expect(advisory.code(status: .findings, errors: true) == 0)
    }

    static func finding(_ rule: Swift.String, _ severity: Diagnostic.Severity) -> Source.Finding {
        Source.Finding(
            rule: Source.Rule.ID(engine: Source.Engine.ID("swift-linter"), token: rule),
            diagnostic: .init(
                location: .init(fileID: "F.swift", filePath: "Sources/M/F.swift", line: 1, column: 1),
                severity: severity,
                identifier: rule,
                message: rule
            ),
            repair: .unavailable(.init(code: "fixture", detail: rule))
        )
    }

    /// swift-institute/Issues#272: a note is a review prompt and never counts; warnings and errors do.
    @Test func `a note is not counted, a warning and an error are`() {
        let counts = Ratchet.counts([
            Self.finding("namespace adoption typealias", .note),
            Self.finding("typealiased namespace bridge", .note),
            Self.finding("comment in source", .warning),
            Self.finding("comment in source", .error),
        ])
        #expect(counts == ["comment in source": 2])
    }

    @Test func `a note over no limit is no overrun`() {
        let counts = Ratchet.counts([Self.finding("namespace adoption typealias", .note)])
        #expect(Ratchet.overruns(repository: "swift-atoms/swift-a", counts: counts, table: Self.table).isEmpty)
    }

    @Test func `the shipped table parses`() {
        #expect(!Ratchet.allowed(for: "swift-compositions/swift-sqlite", in: Ratchet.limits).isEmpty)
    }
}
