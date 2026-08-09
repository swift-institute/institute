import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Composition.State {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct Integration {}
    }
}

extension Institute.Composition.State.Test.Unit {
    private static let record = Institute.Composition.Record(
        consumer: "swift-color",
        dependency: "swift-color-standard",
        declared: ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
        planned: ".package(path: \"/abs/swift-standards/swift-color-standard\")"
    )

    @Test
    func `a record round-trips through JSON`() throws {
        let json = Institute.Composition.Record.serialize(Self.record)
        let decoded = try Institute.Composition.Record.deserialize(json)
        #expect(decoded == Self.record)
    }

    @Test
    func `a ledger round-trips through JSON`() throws {
        let state = Institute.Composition.State(records: [Self.record])
        let decoded = try Institute.Composition.State(jsonString: state.jsonString())
        #expect(decoded == state)
    }

    @Test
    func `record lookup, add, and remove`() {
        let empty = Institute.Composition.State()
        #expect(empty.record(consumer: "swift-color", dependency: "swift-color-standard") == nil)

        let one = empty.adding(Self.record)
        #expect(one.record(consumer: "swift-color", dependency: "swift-color-standard") == Self.record)

        let gone = one.removing(consumer: "swift-color", dependency: "swift-color-standard")
        #expect(gone.records.isEmpty)
    }

    @Test
    func `deserialize rejects a mismatched version`() {
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Composition.State(jsonString: "{\"version\": 999, \"compositions\": []}")
        }
    }
}

extension Institute.Composition.State.Test.Integration {
    @Test
    func `an absent ledger loads as empty`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let root = try File.Directory(validating: base.path)
        #expect(try Institute.Composition.State.load(at: root).records.isEmpty)
    }

    @Test
    func `a saved ledger reloads under the checkout rather than its sibling hierarchy`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let checkout = base.appending(path: "Institute")
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let root = try File.Directory(validating: checkout.path)
        let state = Institute.Composition.State(records: [
            Institute.Composition.Record(
                consumer: "swift-color",
                dependency: "swift-color-standard",
                declared: ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
                planned: ".package(path: \"\(base.path)/swift-standards/swift-color-standard\")"
            )
        ])
        try state.save(at: root)
        #expect(try Institute.Composition.State.load(at: root) == state)

        // The ledger stays in the git-ignored checkout-local .workspace/ directory.
        let ledger = checkout.appending(path: ".workspace/compositions.json")
        #expect(FileManager.default.fileExists(atPath: ledger.path))
        #expect(!FileManager.default.fileExists(atPath: base.appending(path: ".workspace").path))
    }
}
