import Byte
import Institute_Model
import Testing

@testable import Institute_Planner_Application

extension Institute.Planner.Pinned {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Pinned.Test {
    /// A consumer pinned to a published candidate.
    struct Scenario {
        var fixture = Institute.Planner.Fixture()
        let rows: [String]

        init() {
            rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
            fixture.adopt(Institute.Planner.Fixture.candidate, rows: rows)
        }

        func resolve() -> Result<Institute.Planner.Executable, Institute.Planner.Error> {
            do throws(Institute.Planner.Error) {
                return .success(
                    try Institute.Planner.Pinned.executable(
                        consumer: fixture.consumer,
                        release: fixture.release,
                        platform: .macos
                    )
                )
            } catch {
                return .failure(error)
            }
        }

        var binaryName: String {
            let row = rows.first { $0.contains(" macos-arm64 ") } ?? ""
            return "institute-macos-arm64-\(row.split(separator: " ")[2])"
        }
    }
}

extension Institute.Planner.Pinned.Test.Unit {
    @Test func `the pinned planner resolves to the verified published bytes`() throws {
        let scenario = Institute.Planner.Pinned.Test.Scenario()
        let executable = try scenario.resolve().get()
        #expect(executable.binary == scenario.fixture.assets[scenario.binaryName])
        #expect(executable.row.revision.description == Institute.Planner.Fixture.candidate)
        #expect(executable.row.platform == .macos)
    }

    @Test func `the identity records the revision, platform and digests`() throws {
        let scenario = Institute.Planner.Pinned.Test.Scenario()
        let identity = try scenario.resolve().get().identity
        #expect(identity.contains("planner-revision=\(Institute.Planner.Fixture.candidate)\n"))
        #expect(identity.contains("platform=macos-arm64\n"))
        #expect(
            identity.contains(
                "binary-sha256=\(Institute.Planner.Fixture.hex(scenario.fixture.assets[scenario.binaryName] ?? []))\n"
            )
        )
    }
}

extension Institute.Planner.Pinned.Test.`Edge Case` {
    /// The control for the digest check: the same release with the binary's
    /// bytes replaced under its published name resolves nothing.
    @Test func `a binary whose bytes do not hash to the pinned digest is refused`() {
        var scenario = Institute.Planner.Pinned.Test.Scenario()
        scenario.fixture.assets[scenario.binaryName] = [Byte](utf8: "tampered")
        guard case .failure(let error) = scenario.resolve() else {
            Issue.record("a tampered binary was accepted")
            return
        }
        guard case .mismatch(let asset, _, _) = error else {
            Issue.record("expected a digest mismatch, got \(error)")
            return
        }
        #expect(asset == scenario.binaryName)
    }

    @Test func `a pinned row that was never published is refused`() {
        var scenario = Institute.Planner.Pinned.Test.Scenario()
        let typed = "\(Institute.Planner.Fixture.candidate) macos-arm64 \(String(repeating: "e", count: 64)) \(String(repeating: "f", count: 64))"
        scenario.fixture.adopt(Institute.Planner.Fixture.candidate, rows: scenario.rows + [typed])
        guard case .failure(.unpublished(let line)) = scenario.resolve() else {
            Issue.record("a hand-typed row was accepted")
            return
        }
        #expect(line == typed)
    }

    @Test func `a pin without a published release is refused`() {
        var scenario = Institute.Planner.Pinned.Test.Scenario()
        scenario.fixture.assets = [:]
        if case .success = scenario.resolve() {
            Issue.record("a pin with no published release was accepted")
        }
    }
}
