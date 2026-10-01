import File_System
import JSON
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

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
        declared:
            ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
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
        #expect(
            one.record(consumer: "swift-color", dependency: "swift-color-standard") == Self.record
        )

        let gone = one.removing(consumer: "swift-color", dependency: "swift-color-standard")
        #expect(gone.records.isEmpty)
    }

    @Test
    func `records touching one consumer are all reported`() {
        let state = Institute.Composition.State(records: [Self.record])
        #expect(state.records(consumer: "swift-color") == [Self.record])
        #expect(state.records(consumer: "swift-other").isEmpty)
    }

    @Test
    func `deserialize rejects a mismatched version`() {
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Composition.State(
                jsonString: "{\"version\": 999, \"compositions\": []}"
            )
        }
    }
}

extension Institute.Composition.State.Test.Integration {
    @Test
    func `an absent ledger loads as empty`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        try MainFixtureFiles.createDirectory(base)
        defer { try? MainFixtureFiles.remove(base) }

        let root = try File.Directory(validating: base)
        #expect(try Institute.Composition.State.load(at: root).records.isEmpty)
    }

    @Test
    func `a saved ledger reloads under the checkout rather than its sibling hierarchy`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        try MainFixtureFiles.createDirectory(base)
        defer { try? MainFixtureFiles.remove(base) }

        let checkout = MainFixtureFiles.join(base, "Institute")
        try MainFixtureFiles.createDirectory(checkout)
        let root = try File.Directory(validating: checkout)
        let state = Institute.Composition.State(records: [
            Institute.Composition.Record(
                consumer: "swift-color",
                dependency: "swift-color-standard",
                declared:
                    ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
                planned: ".package(path: \"\(base)/swift-standards/swift-color-standard\")"
            )
        ])
        try state.save(at: root)
        #expect(try Institute.Composition.State.load(at: root) == state)

        // The ledger stays in the git-ignored checkout-local .workspace/ directory.
        let ledger = MainFixtureFiles.join(checkout, ".workspace/compositions.json")
        #expect(MainFixtureFiles.exists(ledger))
        #expect(!MainFixtureFiles.exists(MainFixtureFiles.join(base, ".workspace")))
    }
}
