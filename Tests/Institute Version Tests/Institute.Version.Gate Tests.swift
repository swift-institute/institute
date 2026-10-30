import Institute_Model
import Institute_Repository_Policy
import Testing

@testable import Institute_Version

extension Institute.Version.Gate {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Version.Gate.Test {
    typealias Gate = Institute.Version.Gate

    static func run(
        _ suite: Swift.Int,
        event: Swift.String = "push",
        branch: Swift.String = "main",
        path: Swift.String = Gate.workflow,
        completed: Swift.Bool = true
    ) -> Gate.Run {
        .init(suite: suite, event: event, branch: branch, path: path, completed: completed)
    }

    static func check(_ suite: Swift.Int, _ conclusion: Swift.String?) -> Gate.Check {
        .init(suite: suite, completed: conclusion != nil, conclusion: conclusion)
    }
}

extension Institute.Version.Gate.Test.Unit {
    typealias T = Institute.Version.Gate.Test

    @Test func `a successful ci-ok of a push to main passes`() {
        #expect(T.Gate(runs: [T.run(1)], checks: [T.check(1, "success")]) == .passed)
    }

    @Test func `a dispatch run on main attests too`() {
        #expect(T.Gate(runs: [T.run(1, event: "workflow_dispatch")], checks: [T.check(1, "success")]) == .passed)
    }

    @Test func `a running main run is pending`() {
        #expect(T.Gate(runs: [T.run(1, completed: false)], checks: []) == .pending)
        #expect(T.Gate(runs: [T.run(1, completed: false)], checks: [T.check(1, nil)]) == .pending)
    }

    @Test func `a failed ci-ok holds the commit`() {
        #expect(T.Gate(runs: [T.run(1)], checks: [T.check(1, "failure")]) == .failed("failure"))
    }

    @Test func `no run at all is absent`() {
        #expect(T.Gate(runs: [], checks: []) == .absent)
    }
}

extension Institute.Version.Gate.Test.`Edge Case` {
    typealias T = Institute.Version.Gate.Test

    @Test func `a pull request's ci-ok on the same commit does not count`() {
        let runs = [T.run(1, event: "pull_request", branch: "feature")]
        #expect(T.Gate(runs: runs, checks: [T.check(1, "success")]) == .absent)
    }

    @Test func `a push to another branch does not count`() {
        #expect(T.Gate(runs: [T.run(1, branch: "feature")], checks: [T.check(1, "success")]) == .absent)
    }

    @Test func `another workflow's ci-ok does not count`() {
        let runs = [T.run(1, path: ".github/workflows/other.yml")]
        #expect(T.Gate(runs: runs, checks: [T.check(1, "success")]) == .absent)
    }

    @Test func `a later failed run does not revoke an earlier pass`() {
        let gate = T.Gate(runs: [T.run(1), T.run(2)], checks: [T.check(1, "success"), T.check(2, "failure")])
        #expect(gate == .passed)
    }

    @Test func `a cancelled run holds the commit`() {
        #expect(T.Gate(runs: [T.run(1)], checks: [T.check(1, "cancelled")]) == .failed("cancelled"))
    }

    @Test func `a finished main run without ci-ok is a failure, not an absence`() {
        #expect(T.Gate(runs: [T.run(1)], checks: []) == .failed("no \(T.Gate.check) check"))
    }
}

extension Institute.Version.Gate.Test.Integration {
    /// The gate names the check by the job name the generated caller
    /// gives its one reusable call; renaming that job must fail here.
    @Test func `the gate's check is the generated caller's ci-ok`() throws {
        let terminal = Institute.Repository.Policy.Caller.Render.terminal
        let job = try #require(
            terminal.split(separator: "\n").first(where: { $0.hasPrefix("    name: ") })
        )
        #expect(Institute.Version.Gate.check == "\(job.dropFirst("    name: ".count)) / ci-ok")
        #expect(terminal.hasPrefix("name: CI\n"))
        #expect(terminal.contains("      - main\n"))
    }
}
