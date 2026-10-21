import Byte
import FIPS_180_4
import Institute_Model
import Testing

@testable import Institute_Planner_Application

/// The controls of the stale-binary refusal: a binary that is the pinned
/// planner passes, and every other binary is refused with the install
/// command named.
extension Institute.Planner.Freshness {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Freshness.Test {
    /// A consumer pinned to the candidate revision, whose release also
    /// carries an older published revision.
    struct Scenario {
        var fixture = Institute.Planner.Fixture()
        let pinned: [String]
        let older: [String]

        init() {
            older = fixture.publish(Institute.Planner.Fixture.current, run: "100")
            pinned = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
            fixture.adopt(Institute.Planner.Fixture.candidate, rows: older + pinned)
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
                    consumer: fixture.consumer
                )
                return nil
            } catch {
                return error
            }
        }
    }
}

extension Institute.Planner.Freshness.Test.Unit {
    @Test func `the pinned binary is current`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        #expect(scenario.refusal(running: scenario.binary(scenario.pinned)) == nil)
    }
}

extension Institute.Planner.Freshness.Test.`Edge Case` {
    /// The control that makes the refusal fire: the binary of an older
    /// published revision, against a pin that has moved on.
    @Test func `a binary built for another revision than the pin is refused`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        let refusal = scenario.refusal(running: scenario.binary(scenario.older))
        guard case .stale(_, let pinned, let revision, let platform)? = refusal else {
            Issue.record("expected a stale refusal, got \(String(describing: refusal))")
            return
        }
        #expect(revision == Institute.Planner.Fixture.candidate)
        #expect(platform == "macos-arm64")
        #expect(pinned == Institute.Planner.Fixture.hex(scenario.binary(scenario.pinned)))
    }

    @Test func `the refusal names the install command`() {
        let scenario = Institute.Planner.Freshness.Test.Scenario()
        let refusal = scenario.refusal(running: [Byte](utf8: "a local build"))
        #expect(refusal?.description.contains("`institute install`") == true)
    }

    @Test func `a pin without a row for the platform is refused`() {
        var scenario = Institute.Planner.Freshness.Test.Scenario()
        scenario.fixture.adopt(
            Institute.Planner.Fixture.candidate,
            rows: scenario.older
        )
        let refusal = scenario.refusal(running: scenario.binary(scenario.pinned))
        #expect(
            refusal
                == .absent(
                    revision: Institute.Planner.Fixture.candidate,
                    platform: "macos-arm64"
                )
        )
    }
}
