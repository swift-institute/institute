import Byte
import FIPS_180_4
import File_System
import Git_Foundation
import Institute_Model
import JSON
import Testing

@testable import Institute_Planner_Application

extension Institute.Planner.Adoption {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Planner.Adoption.Test {
    /// A consumer on the current planner (run 100) and a release that also
    /// carries the candidate (run 200).
    struct Scenario {
        var fixture = Institute.Planner.Fixture()
        let current: [Swift.String]
        let candidate: [Swift.String]

        init() {
            current = fixture.publish(Institute.Planner.Fixture.current, run: "100")
            candidate = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
            fixture.adopt(Institute.Planner.Fixture.current, rows: current)
        }

        func text(_ path: Swift.String) -> Swift.String {
            Swift.String(decoding: fixture.files[path] ?? [], as: UTF8.self)
        }

        func evidence(
            run: Swift.String = "200",
            verdict: Institute.Planner.Canary.Verdict = .adoptable,
            revision: Swift.String = Institute.Planner.Fixture.candidate,
            rows: [Swift.String]? = nil
        ) -> Institute.Planner.Evidence {
            let outcome = Institute.Planner.Canary.Outcome(status: .clean, code: 0, controls: ["clean": 1])
            return .init(
                verdict: verdict,
                run: run,
                revision: revision,
                rows: rows ?? candidate,
                candidate: .init(row: candidate[1], binary: "", graph: "", toolchain: "Swift version 6.4"),
                current: .init(row: current[1], binary: "", graph: "", toolchain: "Swift version 6.4"),
                xcode: "/Applications/Xcode.app",
                repositories: [
                    .init(
                        repository: "swift-atoms/swift-addition",
                        revision: Swift.String(repeating: "1", count: 40),
                        bundle: "primitives",
                        current: outcome,
                        candidate: outcome
                    )
                ]
            )
        }

        func adoption(
            _ evidence: Institute.Planner.Evidence,
            run: Swift.String = "200"
        ) throws(Institute.Planner.Error) -> Institute.Planner.Adoption {
            try .init(
                evidence: evidence,
                run: run,
                pin: .init(text: text(Institute.Planner.Consumer.pin)),
                ledger: .init(text: text(Institute.Planner.Consumer.ledger)),
                release: fixture.release
            )
        }

        func refusal(_ evidence: Institute.Planner.Evidence, run: Swift.String = "200") -> Institute.Planner.Error? {
            do throws(Institute.Planner.Error) {
                _ = try adoption(evidence, run: run)
                return nil
            } catch {
                return error
            }
        }
    }
}

extension Institute.Planner.Adoption.Test.Unit {
    @Test func `adoption appends the PIN lines verbatim and pins the revision, keeping comments`() throws {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        let adoption = try scenario.adoption(scenario.evidence())

        #expect(adoption.pin == Institute.Planner.Fixture.pin(Institute.Planner.Fixture.candidate))
        #expect(
            adoption.ledger
                == Institute.Planner.Fixture.ledger(scenario.current) + scenario.candidate.map { $0 + "\n" }.joined()
        )
        #expect(adoption.revision.description == Institute.Planner.Fixture.candidate)
        #expect(adoption.message.hasPrefix("Adopt planner \(Institute.Planner.Fixture.candidate) from publish run 200\n"))
        #expect(adoption.message.contains("- swift-atoms/swift-addition: clean -> clean, errors 0 -> 0"))
    }

    @Test func `a ledger without a trailing newline gains one before the appended rows`() throws {
        var scenario = Institute.Planner.Adoption.Test.Scenario()
        scenario.fixture.files[Institute.Planner.Consumer.ledger] = [Byte](
            utf8: Institute.Planner.Fixture.ledger(scenario.current).dropLast().description
        )
        let adoption = try scenario.adoption(scenario.evidence())
        #expect(adoption.ledger.hasSuffix(scenario.current[1] + "\n" + scenario.candidate.joined(separator: "\n") + "\n"))
    }

    @Test func `evidence round-trips through its JSON`() throws {
        let evidence = Institute.Planner.Adoption.Test.Scenario().evidence()
        let decoded = try Institute.Planner.Evidence(jsonString: evidence.jsonString(pretty: true, sortKeys: true))
        #expect(decoded == evidence)
    }
}

extension Institute.Planner.Adoption.Test.`Edge Case` {
    @Test(arguments: [Institute.Planner.Canary.Verdict.differs, .refused])
    func `evidence that is not adoptable is refused`(verdict: Institute.Planner.Canary.Verdict) {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        guard case .evidence = scenario.refusal(scenario.evidence(verdict: verdict)) else {
            Issue.record("expected an evidence refusal for \(verdict)")
            return
        }
    }

    @Test func `evidence for another publish run is refused`() {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        #expect(
            scenario.refusal(scenario.evidence(run: "199"))
                == .evidence("the evidence is for publish run 199, not 200")
        )
    }

    @Test func `evidence whose PIN lines differ from the release's is refused`() {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        guard case .evidence = scenario.refusal(scenario.evidence(rows: [scenario.candidate[0]])) else {
            Issue.record("expected an evidence refusal")
            return
        }
    }

    @Test func `evidence for another revision is refused`() {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        guard case .evidence = scenario.refusal(scenario.evidence(revision: Institute.Planner.Fixture.current)) else {
            Issue.record("expected an evidence refusal")
            return
        }
    }

    @Test func `an adoption whose candidate binary is gone fails the contract`() throws {
        var scenario = Institute.Planner.Adoption.Test.Scenario()
        let row = try Institute.Planner.Row(line: scenario.candidate[0])
        scenario.fixture.assets["institute-linux-x86_64-\(row.binary.hex)"] = nil
        #expect(
            scenario.refusal(scenario.evidence())
                == .missing("release asset institute-linux-x86_64-\(row.binary.hex)")
        )
    }

    @Test func `evidence whose verdict was edited does not decode`() throws {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        var evidence = scenario.evidence(verdict: .differs).json
        let comparison = Institute.Planner.Canary.Comparison(
            repository: "swift-atoms/swift-addition",
            revision: Swift.String(repeating: "1", count: 40),
            bundle: "primitives",
            current: .init(status: .clean, code: 0),
            candidate: .init(status: .findings, code: 1, errors: ["swift-linter a": 1])
        )
        guard var object = evidence.object else {
            Issue.record("evidence is not an object")
            return
        }
        object = object.map { member in
            member.key == "repositories"
                ? (member.key, [comparison].json)
                : member.key == "verdict" ? (member.key, "adoptable".json) : member
        }
        evidence = .object(object)
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Planner.Evidence(json: evidence)
        }
    }
}

extension Institute.Planner.Adoption.Test.Integration {
    /// A consumer checkout on `main` holding the current files in one commit.
    static func checkout(_ scenario: Institute.Planner.Adoption.Test.Scenario) throws -> Swift.String {
        let anchor = try File.Path.Temporary.deterministic(prefix: "institute-planner-adopt", key: "", suffix: "")
        let root = try File.Path.Temporary.sibling(of: anchor, prefix: "institute-planner-adopt-").description
        let git = Git.Client()
        try git.initialize(at: root, bare: false)
        try File(File.Path("\(root)/.git/HEAD")).write.atomic(contentsOf: [Byte](utf8: "ref: refs/heads/main\n"))
        let config = try Institute.Planner.read(Institute.Planner.path("\(root)/.git/config"))
        try File(File.Path("\(root)/.git/config")).write.atomic(
            contentsOf: config + [Byte](utf8: "[user]\n\tname = Planner Tests\n\temail = planner@swift.institute\n")
        )
        for path in Institute.Planner.Adoption.paths {
            try File(File.Path("\(root)/\(path)")).write.atomic(contentsOf: scenario.fixture.files[path] ?? [])
        }
        try git.add(Institute.Planner.Adoption.paths, at: root)
        _ = try git.commit(message: "Adopt the current planner", at: root)
        return root
    }

    @Test func `recording commits exactly the two files once and pushes nothing`() throws {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        let root = try Self.checkout(scenario)
        defer {
            // swift-linter:disable:next try optional
            // REASON: fixture cleanup; residue in the temporary directory must not mask the test's outcome.
            try? File.System.Delete.delete(at: File.Path(root), recursive: true)
        }
        let git = Git.Client()
        let before = try git.head(at: root)
        let adoption = try scenario.adoption(scenario.evidence())

        let commit = try adoption.record(at: root, git: git)

        #expect(commit != before)
        #expect(try git.head(at: root) == commit)
        #expect(try git.count("HEAD", at: root) == 2)
        #expect(try git.ancestor(before, of: commit, at: root))
        #expect(try git.status(at: root).isEmpty)
        let pin = try Institute.Planner.read(Institute.Planner.path("\(root)/\(Institute.Planner.Consumer.pin)"))
        #expect(Swift.String(decoding: pin, as: UTF8.self) == adoption.pin)
        let ledger = try Institute.Planner.read(Institute.Planner.path("\(root)/\(Institute.Planner.Consumer.ledger)"))
        #expect(Swift.String(decoding: ledger, as: UTF8.self) == adoption.ledger)
        #expect(Institute.Planner.Adoption.push(root) == "git -C '\(root)' push origin main")
    }

    @Test func `recording into a dirty checkout is refused and changes nothing`() throws {
        let scenario = Institute.Planner.Adoption.Test.Scenario()
        let root = try Self.checkout(scenario)
        defer {
            // swift-linter:disable:next try optional
            // REASON: fixture cleanup; residue in the temporary directory must not mask the test's outcome.
            try? File.System.Delete.delete(at: File.Path(root), recursive: true)
        }
        try File(File.Path("\(root)/stray.txt")).write.atomic(contentsOf: [Byte](utf8: "stray\n"))
        let git = Git.Client()
        let before = try git.head(at: root)
        let adoption = try scenario.adoption(scenario.evidence())

        #expect(throws: Institute.Planner.Error.self) {
            _ = try adoption.record(at: root, git: git)
        }
        #expect(try git.head(at: root) == before)
        let pin = try Institute.Planner.read(Institute.Planner.path("\(root)/\(Institute.Planner.Consumer.pin)"))
        #expect(Swift.String(decoding: pin, as: UTF8.self) == Institute.Planner.Fixture.pin(Institute.Planner.Fixture.current))
    }
}
