import Byte
import FIPS_180_4
import Institute_Model
import Testing

@testable import Institute_Planner_Application

/// The controls of the stale-binary refusal: a published binary at or after
/// the pin passes; older, unpublished and tampered binaries are refused.
extension Institute.Planner.Freshness {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Freshness.Test {
    /// A consumer pinned to the current revision, whose release also carries
    /// an older publication and a newer main-branch descendant.
    struct Scenario {
        var fixture = Institute.Planner.Fixture()
        let older: [String]
        let pinned: [String]
        let newer: [String]

        init() {
            older = fixture.publish(String(repeating: "c", count: 40), run: "100")
            pinned = fixture.publish(Institute.Planner.Fixture.current, run: "200")
            newer = fixture.publish(Institute.Planner.Fixture.candidate, run: "300")
            fixture.adopt(Institute.Planner.Fixture.current, rows: pinned)
        }

        /// The bytes of the binary published in `rows` for macOS.
        func binary(_ rows: [String]) -> [Byte] {
            let row = rows.first { $0.contains(" macos-arm64 ") } ?? ""
            let digest = row.split(separator: " ")[2]
            return fixture.assets["institute-macos-arm64-\(digest)"] ?? []
        }

        func refusal(running: [Byte]) -> Institute.Planner.Error? {
            do throws(Institute.Planner.Error) {
                try Institute.Planner.Freshness.verify(
                    running: FIPS_180_4.SHA256.digest(running),
                    platform: .macos,
                    consumer: fixture.consumer,
                    release: fixture.release,
                    history: .init { revision, pinned in
                        pinned.description == Institute.Planner.Fixture.current
                            && (
                                revision.description == Institute.Planner.Fixture.current
                                    || revision.description == Institute.Planner.Fixture.candidate
                            )
                    }
                )
                return nil
            } catch {
                return error
            }
        }
    }
}

extension Institute.Planner.Freshness.Test.Unit {
    @Test func `the pinned published binary is current`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        #expect(scenario.refusal(running: scenario.binary(scenario.pinned)) == nil)
    }

    @Test func `a newer published main branch candidate is current`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        #expect(scenario.refusal(running: scenario.binary(scenario.newer)) == nil)
    }
}

extension Institute.Planner.Freshness.Test.`Edge Case` {
    /// The control that makes the refusal fire: the binary of an older
    /// published revision, against a pin that has moved on.
    @Test func `a binary built for another revision than the pin is refused`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        let refusal = scenario.refusal(running: scenario.binary(scenario.older))
        guard case .stale(_, let revision, let platform)? = refusal else {
            Issue.record("expected a stale refusal, got \(String(describing: refusal))")
            return
        }
        #expect(revision == Institute.Planner.Fixture.current)
        #expect(platform == "macos-arm64")
        #expect(refusal?.description.contains("`institute install`") == true)
    }

    @Test func `an unpublished binary is refused and names the install command`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        let refusal = scenario.refusal(running: [Byte](utf8: "a local build"))
        #expect(refusal?.description.contains("`institute install`") == true)
    }

    @Test func `a tampered published binary is refused and names the install command`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        var tampered = scenario.binary(scenario.newer)
        tampered += [Byte](utf8: "tampered")
        let refusal = scenario.refusal(running: tampered)
        #expect(refusal?.description.contains("`institute install`") == true)
    }

    @Test func `a pin without a row for the platform is refused`() {
        var scenario = Institute.Planner.Freshness.Test.Scenario()
        scenario.fixture.adopt(
            Institute.Planner.Fixture.current,
            rows: scenario.pinned.filter { !$0.contains(" macos-arm64 ") }
        )
        let refusal = scenario.refusal(running: scenario.binary(scenario.newer))
        #expect(
            refusal
                == .absent(
                    revision: Institute.Planner.Fixture.current,
                    platform: "macos-arm64"
                )
        )
    }
}
