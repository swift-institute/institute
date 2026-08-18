import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Hierarchy {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Institute.Hierarchy.Test.Unit {
    @Test
    func `a valid id constructs`() throws {
        let id = try Institute.Hierarchy.ID("swift-color")
        #expect(id.value == "swift-color")
        #expect(id.description == "swift-color")
    }

    @Test
    func `an empty id is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Hierarchy.ID("")
        }
    }

    @Test
    func `traversal components are refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Hierarchy.ID(".")
        }
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Hierarchy.ID("..")
        }
    }

    @Test
    func
        `an id containing a path separator is refused, because an id is a registry key, not a path`()
    {
        #expect(throws: (any Swift.Error).self) {
            _ = try Institute.Hierarchy.ID("swift-institute/swift-color")
        }
    }

    @Test
    func `an id round-trips through JSON`() throws {
        let id = try Institute.Hierarchy.ID("swift-color")
        let decoded = try Institute.Hierarchy.ID(json: id.json)
        #expect(decoded == id)
    }

    @Test
    func `ownership has exactly two cases`() {
        let all: [Institute.Hierarchy.Ownership] = [.managed, .adopted]
        #expect(all.count == 2)
        #expect(Set(all.map(\.rawValue)) == ["managed", "adopted"])
    }

    @Test
    func `ownership round-trips through JSON`() throws {
        for ownership: Institute.Hierarchy.Ownership in [.managed, .adopted] {
            let decoded = try Institute.Hierarchy.Ownership(json: ownership.json)
            #expect(decoded == ownership)
        }
    }

    @Test
    func `an unrecognized ownership string is refused`() {
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Hierarchy.Ownership(json: "orphaned".json)
        }
    }

    @Test
    func `relocating a hierarchy changes the locator but never the id`() throws {
        let id = try Institute.Hierarchy.ID("swift-color")
        let before = Institute.Hierarchy(
            id: id,
            locator: File.Directory(try File.Path("/tmp/one")),
            ownership: .managed
        )
        let after = before.relocated(to: File.Directory(try File.Path("/tmp/two")))

        #expect(after.id == before.id)
        #expect(after.id == id)
        #expect(after.locator != before.locator)
        #expect(after.ownership == before.ownership)
    }

    @Test
    func `a hierarchy round-trips through JSON`() throws {
        let value = Institute.Hierarchy(
            id: try Institute.Hierarchy.ID("swift-color"),
            locator: File.Directory(try File.Path("/tmp/swift-color")),
            ownership: .adopted
        )
        let decoded = try Institute.Hierarchy(json: value.json)
        #expect(decoded == value)
    }
}
