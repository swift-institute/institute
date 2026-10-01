import File_System
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

extension Institute.Root {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Root.Test.Unit {
    @Test
    func `a physical checkout owns a sibling materialization hierarchy`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "X/Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(checkout)

        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let canonical = try File.System.Canonical.resolve(File.Path(checkout))

        #expect(root.checkout.path == canonical)
        #expect(root.hierarchy == File.Directory(canonical).parent)
    }

    @Test
    func `a symlinked checkout resolves its physical checkout and sibling hierarchy`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let physical = MainFixtureFiles.join(base, "physical/X/Institute")
        let alias = MainFixtureFiles.join(base, "alias-workspace")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(physical)
        try MainFixtureFiles.createSymbolicLink(alias, toURLOf: physical)

        let root = try Institute.Root(checkout: File.Directory(validating: alias))
        let canonical = try File.System.Canonical.resolve(File.Path(physical))

        #expect(root.checkout.path == canonical)
        #expect(root.hierarchy == File.Directory(canonical).parent)
        #expect(
            root.hierarchy
                != File.Directory(try File.System.Canonical.resolve(File.Path(base)))
        )
    }
}

extension Institute.Root.Test.`Edge Case` {
    @Test
    func `a missing materialization hierarchy is admitted for later creation`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(checkout)
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-standards"][directory: "swift-ietf"]

        try root.preflight(target, under: root.hierarchy)
    }

    @Test
    func `a regular file materialization prefix fails closed`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(checkout)
        _ = MainFixtureFiles.createFile(MainFixtureFiles.join(base, "swift-foundations"), contents: Array("collision".utf8))
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-foundations"][directory: "swift-example"]

        #expect(throws: Institute.Error.self) {
            try root.preflight(target, under: root.hierarchy)
        }
    }

    @Test
    func `a symbolic link materialization prefix fails closed`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "Institute")
        let outside = MainFixtureFiles.join(base, "outside")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(checkout)
        try MainFixtureFiles.createDirectory(outside)
        try MainFixtureFiles.createSymbolicLink(MainFixtureFiles.join(base, "swift-foundations"), toURLOf: outside)
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-foundations"][directory: "swift-example"]

        #expect(throws: Institute.Error.self) {
            try root.preflight(target, under: root.hierarchy)
        }
        #expect(
            !MainFixtureFiles.exists(MainFixtureFiles.join(outside, "swift-example"))
        )
    }
}
