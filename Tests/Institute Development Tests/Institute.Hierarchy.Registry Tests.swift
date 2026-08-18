import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Hierarchy.Registry {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct Integration {}
  }
}

extension Institute.Hierarchy.Registry.Test.Unit {
  @Test
  func `a registry round-trips through JSON`() throws {
    let hierarchy = Institute.Hierarchy(
      id: try Institute.Hierarchy.ID("swift-color"),
      locator: File.Directory(try File.Path("/tmp/swift-color")),
      ownership: .managed
    )
    let registry = Institute.Hierarchy.Registry(hierarchies: [hierarchy])
    let decoded = try Institute.Hierarchy.Registry(jsonString: registry.jsonString())
    #expect(decoded == registry)
  }

  @Test
  func `serialization is deterministic regardless of insertion order in a re-decoded value`() throws {
    let a = Institute.Hierarchy(
      id: try Institute.Hierarchy.ID("swift-color"),
      locator: File.Directory(try File.Path("/tmp/a")),
      ownership: .managed
    )
    let b = Institute.Hierarchy(
      id: try Institute.Hierarchy.ID("swift-shape"),
      locator: File.Directory(try File.Path("/tmp/b")),
      ownership: .adopted
    )
    let registry = Institute.Hierarchy.Registry(hierarchies: [a, b])
    let first = registry.jsonString(pretty: true, sortKeys: true)
    let second = registry.jsonString(pretty: true, sortKeys: true)
    #expect(first == second)
    #expect(first.hasSuffix("}"))
  }

  @Test
  func `deserialize rejects a mismatched version`() {
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Hierarchy.Registry(
        jsonString: "{\"version\": 999, \"hierarchies\": []}"
      )
    }
  }
}

extension Institute.Hierarchy.Registry.Test.Integration {
  private static func temporaryCheckout() throws -> File.Directory {
    let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return try File.Directory(validating: base.path)
  }

  @Test
  func `an absent registry loads as empty`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    #expect(try Institute.Hierarchy.Registry.list(at: checkout).isEmpty)
  }

  @Test
  func `a saved registry round-trips, written pretty and sorted with a trailing newline`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    let root = try File.Directory(validating: checkout.path.description + "/root")
    try FileManager.default.createDirectory(
      atPath: root.path.description,
      withIntermediateDirectories: true
    )

    let id = try Institute.Hierarchy.ID("swift-color")
    try Institute.Hierarchy.Registry.register(
      id: id,
      locator: root,
      ownership: .managed,
      at: checkout
    )

    let ledgerPath = checkout.path.description + "/.workspace/hierarchies.json"
    let raw = try Swift.String(contentsOfFile: ledgerPath, encoding: .utf8)
    #expect(raw.hasSuffix("\n"))
    #expect(!raw.hasSuffix("\n\n"))

    let listed = try Institute.Hierarchy.Registry.list(at: checkout)
    #expect(listed.map(\.id) == [id])
  }

  @Test
  func `a duplicate id fails registration with a typed error`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    let first = try Self.directory(under: checkout, name: "first")
    let second = try Self.directory(under: checkout, name: "second")
    let id = try Institute.Hierarchy.ID("swift-color")

    try Institute.Hierarchy.Registry.register(
      id: id,
      locator: first,
      ownership: .managed,
      at: checkout
    )

    #expect(throws: Institute.Hierarchy.Registry.Error.self) {
      try Institute.Hierarchy.Registry.register(
        id: id,
        locator: second,
        ownership: .managed,
        at: checkout
      )
    }
  }

  @Test
  func `two ids resolving to the same physical directory collide`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    let real = try Self.directory(under: checkout, name: "real")
    let aliasPath = checkout.path.description + "/alias"
    try FileManager.default.createSymbolicLink(
      atPath: aliasPath,
      withDestinationPath: real.path.description
    )
    let alias = try File.Directory(validating: aliasPath)

    try Institute.Hierarchy.Registry.register(
      id: try Institute.Hierarchy.ID("one"),
      locator: real,
      ownership: .managed,
      at: checkout
    )

    #expect(throws: Institute.Hierarchy.Registry.Error.self) {
      try Institute.Hierarchy.Registry.register(
        id: try Institute.Hierarchy.ID("two"),
        locator: alias,
        ownership: .managed,
        at: checkout
      )
    }
  }

  @Test
  func `a missing registered root reports missing, never valid`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    let root = try Self.directory(under: checkout, name: "gone")
    let id = try Institute.Hierarchy.ID("swift-color")
    try Institute.Hierarchy.Registry.register(
      id: id,
      locator: root,
      ownership: .managed,
      at: checkout
    )

    try FileManager.default.removeItem(atPath: root.path.description)

    #expect(throws: Institute.Hierarchy.Registry.Error.self) {
      _ = try Institute.Hierarchy.Registry.status(of: id, at: checkout)
    }

    // The raw registry record is unaffected: `resolve` still reports the
    // locator exactly as registered, it just does not vouch for it.
    let resolved = try Institute.Hierarchy.Registry.resolve(id, at: checkout)
    #expect(resolved == root)
  }

  @Test
  func `forget removes only the registry record, on either ownership`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    for ownership: Institute.Hierarchy.Ownership in [.managed, .adopted] {
      let root = try Self.directory(under: checkout, name: "root-\(ownership.rawValue)")
      let marker = root.path.description + "/marker.txt"
      try "content".write(toFile: marker, atomically: true, encoding: .utf8)

      let id = try Institute.Hierarchy.ID("hierarchy-\(ownership.rawValue)")
      try Institute.Hierarchy.Registry.register(
        id: id,
        locator: root,
        ownership: ownership,
        at: checkout
      )

      try Institute.Hierarchy.Registry.forget(id, at: checkout)

      #expect(throws: Institute.Hierarchy.Registry.Error.self) {
        _ = try Institute.Hierarchy.Registry.resolve(id, at: checkout)
      }
      // The root and its content were never touched by `forget`.
      #expect(FileManager.default.fileExists(atPath: root.path.description))
      #expect(FileManager.default.fileExists(atPath: marker))
    }
  }

  @Test
  func `forgetting an unregistered id fails with a typed error`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    #expect(throws: Institute.Hierarchy.Registry.Error.self) {
      try Institute.Hierarchy.Registry.forget(
        try Institute.Hierarchy.ID("never-registered"),
        at: checkout
      )
    }
  }

  @Test
  func `an id survives a locator change: register, relocate, resolve again, same id`() throws {
    let checkout = try Self.temporaryCheckout()
    defer { try? FileManager.default.removeItem(atPath: checkout.path.description) }

    let before = try Self.directory(under: checkout, name: "before")
    let after = try Self.directory(under: checkout, name: "after")
    let id = try Institute.Hierarchy.ID("swift-color")

    try Institute.Hierarchy.Registry.register(
      id: id,
      locator: before,
      ownership: .managed,
      at: checkout
    )
    #expect(try Institute.Hierarchy.Registry.resolve(id, at: checkout) == before)

    // The locator changes underneath the same id — the id itself is
    // never derived from, or tied to, any particular physical path.
    try Institute.Hierarchy.Registry.forget(id, at: checkout)
    try Institute.Hierarchy.Registry.register(
      id: id,
      locator: after,
      ownership: .managed,
      at: checkout
    )

    let resolved = try Institute.Hierarchy.Registry.resolve(id, at: checkout)
    #expect(resolved == after)
    #expect(resolved != before)

    let listed = try Institute.Hierarchy.Registry.list(at: checkout)
    #expect(listed.map(\.id) == [id])
  }

  private static func directory(under checkout: File.Directory, name: Swift.String) throws
    -> File.Directory
  {
    let path = checkout.path.description + "/" + name
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return try File.Directory(validating: path)
  }
}
