import Source_Report
import Institute_CI_Model
import Institute_Model
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

    @Test func `a rule or repository not listed may have none`() {
        #expect(Ratchet.overruns(repository: "swift-atoms/swift-a", counts: ["new rule": 1], table: Self.table).count == 1)
        #expect(Ratchet.overruns(repository: "swift-atoms/swift-new", counts: ["comment in source": 1], table: Self.table).count == 1)
    }

    @Test func `a strict run fails on an overrun and an advisory one doesn't`() {
        let strict = Institute.CI.Command.Source.Policy.strict
        let advisory = Institute.CI.Command.Source.Policy.advisory
        #expect(strict.code(status: .findings, errors: true) != 0)
        #expect(advisory.code(status: .findings, errors: true) == 0)
    }

    @Test func `the shipped table parses`() {
        #expect(!Ratchet.allowed(for: "swift-compositions/swift-sqlite", in: Ratchet.limits).isEmpty)
    }
}
