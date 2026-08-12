import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Materialization {
  @Suite
  struct Test {
    @Suite struct Unit {}
  }
}

extension Institute.Materialization.Test.Unit {
  @Test
  func `a valid id constructs`() throws {
    let id = try Institute.Materialization.ID("swift-color")
    #expect(id.value == "swift-color")
    #expect(id.description == "swift-color")
  }

  @Test
  func `an empty id is refused`() {
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Materialization.ID("")
    }
  }

  @Test
  func `traversal components are refused`() {
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Materialization.ID(".")
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Materialization.ID("..")
    }
  }

  @Test
  func `an id containing a path separator is refused, because an id is a registry key, not a path`() {
    #expect(throws: (any Swift.Error).self) {
      _ = try Institute.Materialization.ID("swift-institute/swift-color")
    }
  }

  @Test
  func `an id round-trips through JSON`() throws {
    let id = try Institute.Materialization.ID("swift-color")
    let decoded = try Institute.Materialization.ID(json: id.json)
    #expect(decoded == id)
  }

  @Test
  func `ownership has exactly two cases`() {
    let all: [Institute.Materialization.Ownership] = [.managed, .adopted]
    #expect(all.count == 2)
    #expect(Set(all.map(\.rawValue)) == ["managed", "adopted"])
  }

  @Test
  func `ownership round-trips through JSON`() throws {
    for ownership: Institute.Materialization.Ownership in [.managed, .adopted] {
      let decoded = try Institute.Materialization.Ownership(json: ownership.json)
      #expect(decoded == ownership)
    }
  }

  @Test
  func `an unrecognized ownership string is refused`() {
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Materialization.Ownership(json: "orphaned".json)
    }
  }

  @Test
  func `relocating a materialization changes the locator but never the id`() throws {
    let id = try Institute.Materialization.ID("swift-color")
    let before = Institute.Materialization(
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
  func `a materialization round-trips through JSON`() throws {
    let value = Institute.Materialization(
      id: try Institute.Materialization.ID("swift-color"),
      locator: File.Directory(try File.Path("/tmp/swift-color")),
      ownership: .adopted
    )
    let decoded = try Institute.Materialization(json: value.json)
    #expect(decoded == value)
  }
}
