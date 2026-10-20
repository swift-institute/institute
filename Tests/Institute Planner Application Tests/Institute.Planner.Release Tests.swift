import Byte
import FIPS_180_4
import Institute_Model
import Testing

@testable import Institute_Planner_Application

extension Institute.Planner.Release {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Release.Test {
    static func refusal(
        _ body: () throws(Institute.Planner.Error) -> Void
    ) -> Institute.Planner.Error? {
        do throws(Institute.Planner.Error) {
            try body()
            return nil
        } catch {
            return error
        }
    }
}

extension Institute.Planner.Release.Test.Unit {
    @Test func `a publish run's macOS planner verifies against its PIN and SHA256SUMS`() throws {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let release = fixture.release

        let publication = try release.publication(run: "200")
        #expect(publication.revision.description == Institute.Planner.Fixture.candidate)
        #expect(publication.rows.map(\.line) == rows)

        let executable = try release.executable(.macos, of: publication)
        #expect(executable.row.line == rows[1])
        #expect(executable.toolchain == "Swift version 6.4 (macos-arm64)\n")
        #expect(Institute.Planner.Fixture.hex(executable.binary) == executable.row.binary.hex)
    }

    @Test func `the current planner is found by the publication carrying its row`() throws {
        var fixture = Institute.Planner.Fixture()
        fixture.publish(Institute.Planner.Fixture.current, run: "100", salt: "first")
        let rows = fixture.publish(Institute.Planner.Fixture.current, run: "101", salt: "second")
        fixture.adopt(Institute.Planner.Fixture.current, rows: rows)

        let row = try fixture.consumer.current(.macos)
        #expect(row.line == rows[1])
        let publication = try fixture.release.publication(carrying: row)
        #expect(publication.run == "101")
        _ = try fixture.release.executable(.macos, of: publication)
    }
}

extension Institute.Planner.Release.Test.`Edge Case` {
    @Test func `a run with no PIN asset is refused as missing`() {
        var fixture = Institute.Planner.Fixture()
        fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try fixture.release.publication(run: "201")
        }
        #expect(refusal == .missing("PIN asset for publish run 201"))
    }

    @Test func `a run without its SHA256SUMS asset is refused as missing`() {
        var fixture = Institute.Planner.Fixture()
        fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        fixture.assets["SHA256SUMS-\(Institute.Planner.Fixture.candidate)-200"] = nil
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try fixture.release.publication(run: "200")
        }
        #expect(refusal == .missing("SHA256SUMS-\(Institute.Planner.Fixture.candidate)-200"))
    }

    @Test func `a binary that does not hash to its row is refused as a mismatch`() throws {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let row = try Institute.Planner.Row(line: rows[1])
        let name = "institute-macos-arm64-\(row.binary.hex)"
        fixture.assets[name]?.append(contentsOf: [Byte](utf8: "tampered"))
        let release = fixture.release
        let publication = try release.publication(run: "200")
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try release.executable(.macos, of: publication)
        }
        guard case .mismatch(let asset, let expected, _) = refusal else {
            Issue.record("expected a mismatch, got \(String(describing: refusal))")
            return
        }
        #expect(asset == name)
        #expect(expected == row.binary.hex)
    }

    @Test func `a checksum that disagrees with the PIN row is refused as a mismatch`() throws {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let row = try Institute.Planner.Row(line: rows[1])
        let sums = "SHA256SUMS-\(Institute.Planner.Fixture.candidate)-200"
        let graph = "Package.resolved-macos-arm64-\(row.graph.hex)"
        let text = String(decoding: fixture.assets[sums] ?? [], as: UTF8.self)
            .split(separator: "\n")
            .map { $0.hasSuffix(graph) ? "\(String(repeating: "e", count: 64))  \(graph)" : String($0) }
            .joined(separator: "\n")
        fixture.assets[sums] = [Byte](utf8: text)
        let release = fixture.release
        let publication = try release.publication(run: "200")
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try release.executable(.macos, of: publication)
        }
        guard case .mismatch(let asset, _, _) = refusal else {
            Issue.record("expected a mismatch, got \(String(describing: refusal))")
            return
        }
        #expect(asset == "Package.resolved-macos-arm64-\(row.graph.hex)")
    }

    @Test func `a missing graph asset is refused as missing`() throws {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let row = try Institute.Planner.Row(line: rows[1])
        let name = "Package.resolved-macos-arm64-\(row.graph.hex)"
        fixture.assets[name] = nil
        let release = fixture.release
        let publication = try release.publication(run: "200")
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try release.executable(.macos, of: publication)
        }
        #expect(refusal == .missing("release asset \(name)"))
    }

    @Test func `a PIN asset with a row for another revision is malformed`() {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.candidate, run: "200")
        let foreign = Institute.Planner.Fixture.current + rows[0].dropFirst(40)
        fixture.assets["PIN-\(Institute.Planner.Fixture.candidate)-200"] = [Byte](
            utf8: ([foreign] + rows).joined(separator: "\n")
        )
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try fixture.release.publication(run: "200")
        }
        guard case .malformed = refusal else {
            Issue.record("expected malformed, got \(String(describing: refusal))")
            return
        }
    }

    @Test func `a current row no PIN asset carries is refused as unpublished`() throws {
        var fixture = Institute.Planner.Fixture()
        let rows = fixture.publish(Institute.Planner.Fixture.current, run: "100")
        let typed = "\(Institute.Planner.Fixture.current) macos-arm64 \(String(repeating: "c", count: 64)) \(String(repeating: "d", count: 64))"
        fixture.adopt(Institute.Planner.Fixture.current, rows: rows + [typed])
        let row = try fixture.consumer.current(.macos)
        let refusal = Institute.Planner.Release.Test.refusal { () throws(Institute.Planner.Error) in
            _ = try fixture.release.publication(carrying: row)
        }
        #expect(refusal == .unpublished(typed))
    }
}
