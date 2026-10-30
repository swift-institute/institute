import Byte
import FIPS_180_4
import Institute_Model
import Testing

@testable import Institute_Planner

extension Institute.Planner.Row {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Planner.Row.Test {
    static let revision = String(repeating: "a", count: 40)
    static let binary = String(repeating: "c", count: 64)
    static let graph = String(repeating: "d", count: 64)

    static func refusal(_ line: String) -> Institute.Planner.Error? {
        do throws(Institute.Planner.Error) {
            _ = try Institute.Planner.Row(line: line)
            return nil
        } catch {
            return error
        }
    }
}

extension Institute.Planner.Row.Test.Unit {

    @Test func `a published row reads its four fields and keeps its line`() throws {
        let line = "\(Institute.Planner.Row.Test.revision) macos-arm64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph)"
        let row = try Institute.Planner.Row(line: line)
        #expect(row.revision.description == Institute.Planner.Row.Test.revision)
        #expect(row.platform == .macos)
        #expect(row.binary.hex == Institute.Planner.Row.Test.binary)
        #expect(row.graph.hex == Institute.Planner.Row.Test.graph)
        #expect(row.line == line)
    }

    @Test func `rows skip comments and blank lines and keep order`() throws {
        let text = """
            # header
            \(Institute.Planner.Row.Test.revision) linux-x86_64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph)

              # indented comment
            \(Institute.Planner.Row.Test.revision) macos-arm64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph)
            """
        let rows = try Institute.Planner.Row.rows(in: text)
        #expect(rows.map(\.platform) == [.linux, .macos])
    }

    @Test func `a checksum line reads its digest and asset name`() throws {
        let checksum = try Institute.Planner.Checksum(line: "\(Institute.Planner.Row.Test.binary)  institute-macos-arm64-\(Institute.Planner.Row.Test.binary)")
        #expect(checksum.digest.hex == Institute.Planner.Row.Test.binary)
        #expect(checksum.name == "institute-macos-arm64-\(Institute.Planner.Row.Test.binary)")
        let binary = try Institute.Planner.Checksum(line: "\(Institute.Planner.Row.Test.graph) *Package.resolved-linux-x86_64-\(Institute.Planner.Row.Test.graph)")
        #expect(binary.name == "Package.resolved-linux-x86_64-\(Institute.Planner.Row.Test.graph)")
    }

    @Test func `a pin reads its one revision under comments`() throws {
        let pin = try Institute.Planner.Pin(text: "# comment\n\n\(Institute.Planner.Row.Test.revision)\n")
        #expect(pin.revision.description == Institute.Planner.Row.Test.revision)
    }
}

extension Institute.Planner.Row.Test.`Edge Case` {

    @Test func `a row with a trailing field is malformed`() {
        let line = "\(Institute.Planner.Row.Test.revision) macos-arm64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph) extra"
        guard case .malformed = Institute.Planner.Row.Test.refusal(line) else {
            Issue.record("expected malformed, got \(String(describing: Institute.Planner.Row.Test.refusal(line)))")
            return
        }
    }

    @Test func `a row with a missing field is malformed`() {
        guard case .malformed = Institute.Planner.Row.Test.refusal("\(Institute.Planner.Row.Test.revision) macos-arm64 \(Institute.Planner.Row.Test.binary)") else {
            Issue.record("expected malformed")
            return
        }
    }

    @Test func `a row naming an unknown platform is refused by platform`() {
        let line = "\(Institute.Planner.Row.Test.revision) windows-x86_64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph)"
        #expect(Institute.Planner.Row.Test.refusal(line) == .platform("windows-x86_64"))
    }

    @Test(arguments: [
        "short",
        String(repeating: "C", count: 64),
        String(repeating: "c", count: 63),
        String(repeating: "c", count: 65),
        String(repeating: "g", count: 64),
    ])
    func `a row with a malformed digest is malformed`(digest: String) {
        let line = "\(Institute.Planner.Row.Test.revision) linux-x86_64 \(digest) \(Institute.Planner.Row.Test.graph)"
        guard case .malformed = Institute.Planner.Row.Test.refusal(line) else {
            Issue.record("expected malformed for digest \(digest)")
            return
        }
    }

    @Test(arguments: ["main", String(repeating: "A", count: 40), String(repeating: "a", count: 39)])
    func `a row with a malformed revision is malformed`(revision: String) {
        let line = "\(revision) linux-x86_64 \(Institute.Planner.Row.Test.binary) \(Institute.Planner.Row.Test.graph)"
        guard case .malformed = Institute.Planner.Row.Test.refusal(line) else {
            Issue.record("expected malformed for revision \(revision)")
            return
        }
    }

    @Test(arguments: [
        "\(String(repeating: "c", count: 64)) institute-macos-arm64",
        "\(String(repeating: "c", count: 64))  ",
        "\(String(repeating: "c", count: 64))  two names",
        "\(String(repeating: "c", count: 63))   institute-macos-arm64",
        "\(String(repeating: "c", count: 64))  dir/institute-macos-arm64",
    ])
    func `a malformed checksum line is refused`(line: String) {
        #expect(throws: Institute.Planner.Error.self) {
            _ = try Institute.Planner.Checksum(line: line)
        }
    }

    @Test func `a checksum list naming one asset twice is ambiguous`() {
        let line = "\(Institute.Planner.Row.Test.binary)  institute-macos-arm64"
        #expect(throws: Institute.Planner.Error.ambiguous("checksum for institute-macos-arm64")) {
            _ = try Institute.Planner.Checksum.checksums(in: line + "\n" + line + "\n")
        }
    }

    @Test(arguments: [
        "# only a comment\n",
        "\(String(repeating: "a", count: 40))\n\(String(repeating: "b", count: 40))\n",
        "main\n",
        "  \(String(repeating: "a", count: 40))\n",
    ])
    func `a pin that is not exactly one revision line is refused`(text: String) {
        #expect(throws: Institute.Planner.Error.self) {
            _ = try Institute.Planner.Pin(text: text)
        }
    }

    @Test func `publication asset names read their revision and run`() throws {
        let revision = try Institute.Planner.Revision(Institute.Planner.Row.Test.revision)
        #expect(
            Institute.Planner.Asset(publication: "ANCESTORS-\(revision)-1234")
                == .ancestry(revision, run: "1234")
        )
        #expect(
            Institute.Planner.Asset(publication: "PIN-\(revision)-1234") == .pin(revision, run: "1234")
        )
        #expect(
            Institute.Planner.Asset(publication: "SHA256SUMS-\(revision)-1234") == .sums(revision, run: "1234")
        )
        #expect(Institute.Planner.Asset(publication: "PIN-\(revision)-12a4") == nil)
        #expect(Institute.Planner.Asset(publication: "PIN-main-1234") == nil)
        #expect(Institute.Planner.Asset(publication: "institute-macos-arm64-\(revision)") == nil)
    }
}
