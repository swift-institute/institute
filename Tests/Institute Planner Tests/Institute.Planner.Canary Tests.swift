import Byte
import FIPS_180_4
import File_System
import Institute_Model
import Source_Report
import Synchronization
import Testing

@testable import Institute_Planner

extension Institute.Planner.Canary {
    @Suite struct Test {
        @Suite struct Integration {}
    }
}

extension Institute.Planner.Canary.Test {
    /// Every clone and run the fake runner was asked for, in order.
    final class Calls: Sendable {
        private let lines = Mutex<[Swift.String]>([])

        func append(_ line: Swift.String) { lines.withLock { $0.append(line) } }

        var all: [Swift.String] { lines.withLock { $0 } }
    }

    static let revision = Swift.String(repeating: "1", count: 40)
    static let repository = "swift-atoms/swift-addition"

    /// A runner whose clones are empty directories at `revision` and whose
    /// planners answer by binary name.
    static func runner(
        current: Swift.String,
        candidate: Swift.String,
        calls: Calls
    ) -> Institute.Planner.Canary.Runner {
        .init(
            clone: { remote, directory throws(Institute.Planner.Error) in
                calls.append("clone \(remote) \(directory)")
                try Institute.Planner.directory(Institute.Planner.path(directory))
                return try .init(revision)
            },
            execute: { executable, arguments throws(Institute.Planner.Error) in
                calls.append("run \(executable) \(arguments.joined(separator: " "))")
                return executable.hasSuffix("institute-candidate")
                    ? .init(code: 0, output: candidate)
                    : .init(code: 0, output: current)
            }
        )
    }

    static func work() throws -> Swift.String {
        let anchor = try File.Path.Temporary.deterministic(prefix: "institute-planner-canary-test", key: "", suffix: "")
        return try File.Path.Temporary.sibling(of: anchor, prefix: "institute-planner-canary-test-").description
    }

    static func scenario() -> Institute.Planner.Fixture {
        var fixture = Institute.Planner.Fixture()
        let current = fixture.publish(Institute.Planner.Fixture.current, run: "100")
        fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        fixture.adopt(Institute.Planner.Fixture.current, rows: current)
        return fixture
    }
}

extension Institute.Planner.Canary.Test.Integration {
    @Test func `identical planners make the publish run adoptable`() throws {
        let fixture = Institute.Planner.Canary.Test.scenario()
        let work = try Institute.Planner.Canary.Test.work()
        defer {
            // swift-linter:disable:next try optional
            // REASON: fixture cleanup; residue in the temporary directory must not mask the test's outcome.
            try? File.System.Delete.delete(at: File.Path(work), recursive: true)
        }
        let report = Institute.Planner.Canary.Outcome.Test.Report.output(
            Institute.Planner.Canary.Outcome.Test.Report.report()
        )
        let calls = Institute.Planner.Canary.Test.Calls()
        let evidence = Institute.Planner.Canary.evidence(
            run: "200",
            repositories: [Institute.Planner.Canary.Test.repository],
            work: work,
            xcode: "/Applications/Xcode.app",
            release: fixture.release,
            consumer: fixture.consumer,
            runner: Institute.Planner.Canary.Test.runner(current: report, candidate: report, calls: calls)
        )

        #expect(evidence.verdict == .adoptable, "\(evidence.refusal)")
        #expect(evidence.revision == Institute.Planner.Fixture.candidate)
        #expect(evidence.repositories.map(\.bundle) == ["primitives"])
        #expect(evidence.current?.row.hasPrefix("\(Institute.Planner.Fixture.current) macos-arm64 ") == true)
        let subject = "\(work)/swift-atoms/swift-addition/subject"
        #expect(
            calls.all == [
                "clone https://github.com/swift-atoms/swift-addition.git \(subject)",
                "run \(work)/planner/institute-current ci -- source --exit-policy strict --repository swift-atoms/swift-addition --revision \(Institute.Planner.Canary.Test.revision) --root \(subject) --bundle primitives --xcode-application /Applications/Xcode.app",
                "clone file://\(work)/swift-atoms/swift-addition/current \(subject)",
                "run \(work)/planner/institute-candidate ci -- source --exit-policy strict --repository swift-atoms/swift-addition --revision \(Institute.Planner.Canary.Test.revision) --root \(subject) --xcode-application /Applications/Xcode.app",
            ]
        )
        let installed = try Institute.Planner.read(Institute.Planner.path("\(work)/planner/institute-candidate"))
        #expect(Institute.Planner.Fixture.hex(installed) == (try fixture.release.publication(run: "200")).row(for: .macos).binary.hex)
    }

    @Test func `a candidate that gains an error differs`() throws {
        let fixture = Institute.Planner.Canary.Test.scenario()
        let work = try Institute.Planner.Canary.Test.work()
        defer {
            // swift-linter:disable:next try optional
            // REASON: fixture cleanup; residue in the temporary directory must not mask the test's outcome.
            try? File.System.Delete.delete(at: File.Path(work), recursive: true)
        }
        let report = Institute.Planner.Canary.Outcome.Test.Report.self
        let evidence = Institute.Planner.Canary.evidence(
            run: "200",
            repositories: [Institute.Planner.Canary.Test.repository],
            work: work,
            xcode: "/Applications/Xcode.app",
            release: fixture.release,
            consumer: fixture.consumer,
            runner: Institute.Planner.Canary.Test.runner(
                current: report.output(report.report()),
                candidate: report.output(report.report(findings: [report.finding(.error)])),
                calls: .init()
            )
        )
        #expect(evidence.verdict == .differs)
        #expect(evidence.repositories.first?.isRegressed == true)
    }

    @Test func `a tampered candidate binary refuses before anything runs`() throws {
        var fixture = Institute.Planner.Canary.Test.scenario()
        let row = try fixture.release.publication(run: "200").row(for: .macos)
        fixture.assets["institute-macos-arm64-\(row.binary.hex)"]?.append(contentsOf: [Byte](utf8: "tampered"))
        let calls = Institute.Planner.Canary.Test.Calls()
        let evidence = Institute.Planner.Canary.evidence(
            run: "200",
            repositories: [Institute.Planner.Canary.Test.repository],
            work: try Institute.Planner.Canary.Test.work(),
            xcode: "/Applications/Xcode.app",
            release: fixture.release,
            consumer: fixture.consumer,
            runner: Institute.Planner.Canary.Test.runner(current: "", candidate: "", calls: calls)
        )
        #expect(evidence.verdict == .refused)
        #expect(evidence.verdict.code == 2)
        #expect(calls.all.isEmpty)
    }
}
