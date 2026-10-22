import File_System
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
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
    func `a checkout directory resolves by its identity`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "X/Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.checkout(checkout)

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
        try MainFixtureFiles.checkout(physical)
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

    @Test
    func `a nested directory resolves its containing checkout`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "X/Institute")
        let nested = MainFixtureFiles.join(checkout, "Sources/Feature")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.checkout(checkout)
        try MainFixtureFiles.createDirectory(nested)

        let root = try Institute.Root(checkout: File.Directory(validating: nested))
        let canonical = try File.System.Canonical.resolve(File.Path(checkout))

        #expect(root.checkout.path == canonical)
        #expect(root.hierarchy == File.Directory(canonical).parent)
    }
}

extension Institute.Root.Test.`Edge Case` {
    @Test
    func `a directory outside an Institute checkout fails at root resolution`() throws {
        let outside = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        defer { try? MainFixtureFiles.remove(outside) }
        try MainFixtureFiles.createDirectory(outside)
        let canonical = try File.System.Canonical.resolve(File.Path(outside))
        let starting = try File.Directory(validating: outside)

        do throws(Institute.Error) {
            _ = try Institute.Root(checkout: starting)
            Issue.record("expected root resolution to fail")
        } catch {
            #expect(error.description == "not inside an Institute checkout: \(canonical)")
        }
    }

    @Test
    func `a missing materialization hierarchy is admitted for later creation`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.checkout(checkout)
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-standards"][directory: "swift-ietf"]

        try root.preflight(target, under: root.hierarchy)
    }

    @Test
    func `a regular file materialization prefix fails closed`() throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        let checkout = MainFixtureFiles.join(base, "Institute")
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.checkout(checkout)
        _ = MainFixtureFiles.createFile(MainFixtureFiles.join(base, "swift-compositions"), contents: Array("collision".utf8))
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-compositions"][directory: "swift-example"]

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
        try MainFixtureFiles.checkout(checkout)
        try MainFixtureFiles.createDirectory(outside)
        try MainFixtureFiles.createSymbolicLink(MainFixtureFiles.join(base, "swift-compositions"), toURLOf: outside)
        let root = try Institute.Root(checkout: File.Directory(validating: checkout))
        let target = root.hierarchy[directory: "swift-compositions"][directory: "swift-example"]

        #expect(throws: Institute.Error.self) {
            try root.preflight(target, under: root.hierarchy)
        }
        #expect(
            !MainFixtureFiles.exists(MainFixtureFiles.join(outside, "swift-example"))
        )
    }
}
