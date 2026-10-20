import Institute_Model
import Testing

@testable import Institute_Planner_Application

extension Institute.Planner.Canary.Comparison {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Canary.Comparison.Test {
    static let clean = Institute.Planner.Canary.Outcome(
        status: .clean,
        code: 0,
        controls: ["clean": 3]
    )

    static func findings(_ errors: [String: Int]) -> Institute.Planner.Canary.Outcome {
        .init(status: .findings, code: 1, errors: errors, controls: ["clean": 3])
    }

    static func compare(
        _ current: Institute.Planner.Canary.Outcome,
        _ candidate: Institute.Planner.Canary.Outcome
    ) -> Institute.Planner.Canary.Comparison {
        .init(
            repository: "swift-atoms/swift-addition",
            revision: String(repeating: "1", count: 40),
            bundle: "primitives",
            current: current,
            candidate: candidate
        )
    }
}

extension Institute.Planner.Canary.Comparison.Test.Unit {
    @Test func `identical outcomes are adoptable with no differences`() {
        let findings = Institute.Planner.Canary.Comparison.Test.findings(["swift-linter rule": 2])
        let comparisons = [
            Institute.Planner.Canary.Comparison.Test.compare(
                Institute.Planner.Canary.Comparison.Test.clean,
                Institute.Planner.Canary.Comparison.Test.clean
            ),
            Institute.Planner.Canary.Comparison.Test.compare(findings, findings),
        ]
        #expect(comparisons.allSatisfy { $0.differences.isEmpty })
        #expect(Institute.Planner.Canary.Verdict(comparisons) == .adoptable)
    }

    @Test func `a new error differs`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.findings(["swift-linter a": 1]),
            Institute.Planner.Canary.Comparison.Test.findings(["swift-linter a": 1, "swift-linter b": 1])
        )
        #expect(comparison.differences == [.init(.regression, "swift-linter b: errors 0 -> 1")])
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .differs)
    }

    @Test func `a clean canary gaining an error differs on status and count`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.clean,
            Institute.Planner.Canary.Comparison.Test.findings(["swift-linter a": 1])
        )
        #expect(comparison.differences.map(\.kind) == [.regression, .regression])
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .differs)
    }

    @Test func `a turn to unmeasured differs`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.clean,
            .init(status: .unmeasured, code: 2, unmeasured: ["swift-linter: no-summary: absent"], controls: ["clean": 3])
        )
        #expect(
            comparison.differences == [
                .init(.regression, "status clean -> unmeasured"),
                .init(.regression, "newly unmeasured: swift-linter: no-summary: absent"),
            ]
        )
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .differs)
    }

    @Test func `fewer errors are adoptable but listed`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.findings(["swift-linter a": 3]),
            Institute.Planner.Canary.Comparison.Test.findings(["swift-linter a": 1])
        )
        #expect(comparison.differences == [.init(.improvement, "swift-linter a: errors 3 -> 1")])
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .adoptable)
    }
}

extension Institute.Planner.Canary.Comparison.Test.`Edge Case` {
    @Test func `a crashed candidate differs`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.clean,
            .init(status: .crashed, code: nil)
        )
        #expect(comparison.differences == [.init(.regression, "the candidate planner produced no report (exit by signal)")])
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .differs)
    }

    @Test func `a crashed current planner also blocks adoption`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            .init(status: .crashed, code: 70),
            Institute.Planner.Canary.Comparison.Test.clean
        )
        #expect(comparison.isRegressed)
    }

    @Test func `a lost or failing control differs and a gained clean control does not`() {
        let fewer = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.clean,
            .init(status: .clean, code: 0, controls: ["clean": 2])
        )
        #expect(fewer.differences == [.init(.regression, "controls clean 3 -> 2")])
        let more = Institute.Planner.Canary.Comparison.Test.compare(
            Institute.Planner.Canary.Comparison.Test.clean,
            .init(status: .clean, code: 0, controls: ["clean": 4])
        )
        #expect(more.differences == [.init(.improvement, "controls clean 3 -> 4")])
    }

    @Test func `an unmeasured current planner now measuring is an improvement`() {
        let comparison = Institute.Planner.Canary.Comparison.Test.compare(
            .init(status: .unmeasured, code: 2, unmeasured: ["control x: missing: absent"], controls: ["clean": 3]),
            Institute.Planner.Canary.Comparison.Test.clean
        )
        #expect(comparison.differences.allSatisfy { $0.kind == .improvement })
        #expect(Institute.Planner.Canary.Verdict([comparison]) == .adoptable)
    }

    @Test func `no compared canary is not adoptable`() {
        #expect(Institute.Planner.Canary.Verdict([]) == .differs)
    }
}
