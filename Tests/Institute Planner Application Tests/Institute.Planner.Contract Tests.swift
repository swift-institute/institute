import Byte
import FIPS_180_4
import Institute_Model
import Testing

@testable import Institute_Planner_Application

/// The controls of `verify-planner-pins-tests.sh`, case for case, against
/// the Swift contract: the two must accept and refuse the same inputs.
extension Institute.Planner.Contract {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Contract.Test {
    static let old = String(repeating: "b", count: 40)

    /// A release holding one published planner per platform, a pin on it,
    /// and a planner file carrying an older revision's row before its rows.
    struct Scenario {
        var fixture = Institute.Planner.Fixture()
        var rows: [String]
        var pin: String
        var ledger: [String]

        init() {
            rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
            pin = "# comment\n\(Institute.Planner.Fixture.candidate)\n"
            ledger =
                [
                    "# rows",
                    "\(Institute.Planner.Contract.Test.old) linux-x86_64 \(String(repeating: "c", count: 64)) \(String(repeating: "d", count: 64))",
                ] + rows
        }

        func row(_ platform: Institute.Planner.Platform) -> String {
            rows.first { $0.contains(" \(platform.rawValue) ") } ?? ""
        }

        /// The PIN asset republished without `platform`'s line.
        mutating func unpublish(_ platform: Institute.Planner.Platform) {
            fixture.assets["PIN-\(Institute.Planner.Fixture.candidate)-200"] = [Byte](
                utf8: rows.filter { !$0.contains(" \(platform.rawValue) ") }.joined(separator: "\n") + "\n"
            )
        }

        func verify() -> Institute.Planner.Error? {
            do throws(Institute.Planner.Error) {
                _ = try Institute.Planner.Contract.verify(
                    pin: Institute.Planner.Pin(text: pin),
                    ledger: Institute.Planner.Ledger(text: ledger.joined(separator: "\n") + "\n"),
                    release: fixture.release
                )
                return nil
            } catch {
                return error
            }
        }
    }
}

extension Institute.Planner.Contract.Test.Unit {
    @Test func `published rows for both platforms pass`() {
        #expect(Institute.Planner.Contract.Test.Scenario().verify() == nil)
    }

    @Test func `a repeated published row passes`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.ledger.append(scenario.row(.linux))
        #expect(scenario.verify() == nil)
    }

    /// The positive control for the publication check: the hand-typed-row
    /// scenario below, with its row published, passes every other check.
    /// The refusal there is therefore the publication check's alone.
    @Test func `the hand-typed-row scenario passes once its row is published`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.unpublish(.macos)
        scenario.fixture.assets["PIN-\(Institute.Planner.Fixture.candidate)-201"] = [Byte](
            utf8: scenario.row(.macos) + "\n"
        )
        #expect(scenario.verify() == nil)
    }
}

extension Institute.Planner.Contract.Test.`Edge Case` {
    @Test func `a row typed by hand, never published, is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.unpublish(.macos)
        #expect(scenario.verify() == .unpublished(scenario.row(.macos)))
    }

    @Test func `the last row wins and naming a missing binary is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        let extra = "\(Institute.Planner.Fixture.candidate) linux-x86_64 \(String(repeating: "e", count: 64)) \(String(repeating: "f", count: 64))"
        scenario.ledger.append(extra)
        scenario.fixture.assets["PIN-\(Institute.Planner.Fixture.candidate)-201"] = [Byte](utf8: extra + "\n")
        #expect(
            scenario.verify()
                == .missing("release asset institute-linux-x86_64-\(String(repeating: "e", count: 64))")
        )
    }

    @Test func `a pinned revision without a macOS row is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.ledger.removeAll { $0.contains(" macos-arm64 ") }
        #expect(
            scenario.verify()
                == .absent(revision: Institute.Planner.Fixture.candidate, platform: "macos-arm64")
        )
    }

    /// The old revision keeps a Linux row, so — as in the shell contract,
    /// which checks Linux first — the refusal is that row being unpublished.
    @Test func `a pin naming a revision with no published rows is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.pin = "\(Institute.Planner.Contract.Test.old)\n"
        #expect(scenario.verify() == .unpublished(scenario.ledger[1]))
        scenario.ledger.remove(at: 1)
        #expect(
            scenario.verify()
                == .absent(revision: Institute.Planner.Contract.Test.old, platform: "linux-x86_64")
        )
    }

    @Test func `two pin lines are refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.pin = "\(Institute.Planner.Fixture.candidate)\n\(Institute.Planner.Contract.Test.old)\n"
        guard case .malformed = scenario.verify() else {
            Issue.record("expected malformed")
            return
        }
    }

    @Test func `a pin that is not a revision is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.pin = "main\n"
        guard case .malformed = scenario.verify() else {
            Issue.record("expected malformed")
            return
        }
    }

    @Test func `a malformed digest is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.ledger.append("\(Institute.Planner.Fixture.candidate) linux-x86_64 short \(String(repeating: "d", count: 64))")
        guard case .malformed = scenario.verify() else {
            Issue.record("expected malformed")
            return
        }
    }

    @Test func `an unknown platform is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.ledger.append("\(Institute.Planner.Fixture.candidate) windows-x86_64 \(String(repeating: "c", count: 64)) \(String(repeating: "d", count: 64))")
        #expect(scenario.verify() == .platform("windows-x86_64"))
    }

    @Test func `a trailing field is refused`() {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        scenario.ledger.append(scenario.row(.macos) + " extra")
        guard case .malformed = scenario.verify() else {
            Issue.record("expected malformed")
            return
        }
    }

    @Test func `a replaced binary is refused`() throws {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        let row = try Institute.Planner.Row(line: scenario.row(.linux))
        scenario.fixture.assets["institute-linux-x86_64-\(row.binary.hex)"]?.append(contentsOf: [Byte](utf8: "tampered\n"))
        guard case .mismatch = scenario.verify() else {
            Issue.record("expected a mismatch")
            return
        }
    }

    @Test func `a missing graph is refused`() throws {
        var scenario = Institute.Planner.Contract.Test.Scenario()
        let row = try Institute.Planner.Row(line: scenario.row(.macos))
        scenario.fixture.assets["Package.resolved-macos-arm64-\(row.graph.hex)"] = nil
        #expect(scenario.verify() == .missing("release asset Package.resolved-macos-arm64-\(row.graph.hex)"))
    }
}
