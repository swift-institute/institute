import File_System
import Foundation
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

extension Institute.Selection {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Institute.Selection.Test {
  static var inventory: Institute.Configuration {
    .init(
      version: 1,
      scope: "test",
      swift: "6.3.3",
      xcode: "26.6",
      repositories: [
        repository(owner: "swift-foundations", name: "swift-color", layer: .foundations),
        repository(
          owner: "swift-foundations",
          name: "swift-unselected",
          layer: .foundations
        ),
        repository(
          owner: "swift-primitives",
          name: "swift-dimension-primitives",
          layer: .primitives
        ),
      ]
    )
  }

  static func key(
    owner: Swift.String,
    name: Swift.String
  ) -> Institute.Repository.Key {
    .init(owner: .init(owner), name: .init(name))
  }

  static func repository(
    owner: Swift.String,
    name: Swift.String,
    layer: Institute.Layer
  ) -> Institute.Repository {
    let key = key(owner: owner, name: name)
    return .init(
      name: key.name.underlying,
      url: key.url,
      organization: key.owner.underlying,
      layer: layer
    )
  }
}

extension Institute.Selection.Test.Unit {
  @Test
  func `Resolution preserves inventory order rather than selection order`() throws {
    let selection = Institute.Selection(
      version: 1,
      repositories: [
        Institute.Selection.Test.key(
          owner: "swift-primitives",
          name: "swift-dimension-primitives"
        ),
        Institute.Selection.Test.key(
          owner: "swift-foundations",
          name: "swift-color"
        ),
      ]
    )

    let resolved = try selection.resolved(
      in: Institute.Selection.Test.inventory,
      origin: .committed(count: selection.repositories.count)
    )

    #expect(
      resolved.repositories.map(\.name)
        == ["swift-color", "swift-dimension-primitives"]
    )
    #expect(!resolved.repositories.map(\.name).contains("swift-unselected"))
  }

  @Test
  func `Repository keys serialize as canonical owner and name identities`() throws {
    let key = Institute.Selection.Test.key(
      owner: "swift-primitives",
      name: "swift-dimension-primitives"
    )

    let encoded = key.jsonString()
    let decoded = try Institute.Repository.Key(jsonString: encoded)

    #expect(encoded == "\"swift-primitives/swift-dimension-primitives\"")
    #expect(decoded == key)
  }
}

extension Institute.Selection.Test.`Edge Case` {
  @Test
  func `Unsupported version duplicate and empty selections fail closed`() {
    let key = Institute.Selection.Test.key(
      owner: "swift-primitives",
      name: "swift-dimension-primitives"
    )

    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection(version: 2, repositories: [key]).validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection(version: 1, repositories: [key, key]).validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection(version: 1, repositories: []).validated()
    }
  }

  @Test
  func `Unknown repository fails resolution`() {
    let selection = Institute.Selection(
      version: 1,
      repositories: [
        Institute.Selection.Test.key(
          owner: "swift-foundations",
          name: "swift-unknown"
        )
      ]
    )

    #expect(throws: Institute.Error.self) {
      _ = try selection.resolved(
        in: Institute.Selection.Test.inventory,
        origin: .committed(count: selection.repositories.count)
      )
    }
  }

  @Test
  func `Malformed identities unexpected fields and duplicate members fail decoding`() {
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection(
        jsonString: """
          {
            "version": 1,
            "repositories": ["swift-foundations"]
          }
          """
      )
    }
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection(
        jsonString: """
          {
            "version": 1,
            "repositories": ["swift-foundations/swift-color"],
            "scope": "proof"
          }
          """
      )
    }
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection(
        jsonString: """
          {
            "version": 1,
            "repositories": ["swift-foundations/swift-color"],
            "repositories": ["swift-primitives/swift-dimension-primitives"]
          }
          """
      )
    }
  }
}

extension Institute.Selection.Test.Integration {
  @Test
  func `Missing and malformed selection files fail loading`() throws {
    let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: location) }
    try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
    let root = try File.Directory(validating: location.path)

    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.load(at: root)
    }

    try Data("{".utf8).write(
      to: location.appending(path: "Selection.json"),
      options: .atomic
    )
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.load(at: root)
    }
  }
}

// MARK: - Local override

extension Institute.Selection.Test {
  static var color: Institute.Repository.Key {
    key(owner: "swift-foundations", name: "swift-color")
  }

  static var dimension: Institute.Repository.Key {
    key(owner: "swift-primitives", name: "swift-dimension-primitives")
  }

  static var unselected: Institute.Repository.Key {
    key(owner: "swift-foundations", name: "swift-unselected")
  }

  /// The committed policy the override tests depart from.
  static var committed: Institute.Selection {
    .init(version: 1, repositories: [color])
  }

  static func override(
    version: Swift.Int = 1,
    add: [Institute.Repository.Key] = [],
    remove: [Institute.Repository.Key] = []
  ) -> Institute.Selection.Override {
    .init(version: version, add: add, remove: remove)
  }

  /// A disposable checkout carrying the given documents verbatim.
  static func checkout(
    selection: Swift.String?,
    override: Swift.String? = nil
  ) throws -> (root: File.Directory, remove: () -> Void) {
    let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
    if let selection {
      try Data(selection.utf8).write(
        to: location.appending(path: "Selection.json"),
        options: .atomic
      )
    }
    if let override {
      try Data(override.utf8).write(
        to: location.appending(path: "Selection.local.json"),
        options: .atomic
      )
    }
    return (
      try File.Directory(validating: location.path),
      { try? FileManager.default.removeItem(at: location) }
    )
  }

  static let committedDocument = """
    {
      "version": 1,
      "repositories": ["swift-foundations/swift-color"]
    }
    """
}

extension Institute.Selection.Test.Unit {
  @Test
  func `An override adds to and removes from the committed selection`() throws {
    let merged = try Institute.Selection.Test.override(
      add: [Institute.Selection.Test.dimension, Institute.Selection.Test.unselected],
      remove: [Institute.Selection.Test.color]
    )
    .applied(to: Institute.Selection.Test.committed)

    #expect(
      merged.repositories == [
        Institute.Selection.Test.dimension,
        Institute.Selection.Test.unselected,
      ]
    )
  }

  @Test
  func `An origin without an override names the committed document alone`() {
    let origin = Institute.Selection.Origin.committed(count: 5)

    #expect(origin.description == "selection: Selection.json — 5 selected; no local override")
    #expect(origin.effective == 5)
    #expect(origin.added.isEmpty)
    #expect(origin.removed.isEmpty)
  }

  @Test
  func `An overridden origin states both documents and names every withheld package`() {
    let origin = Institute.Selection.Origin.overridden(
      committed: 5,
      added: [Institute.Selection.Test.dimension],
      removed: [Institute.Selection.Test.color]
    )

    #expect(origin.effective == 5)
    #expect(origin.description.contains("Selection.json — 5 selected"))
    #expect(origin.description.contains("Selection.local.json — 1 added, 1 removed"))
    #expect(origin.description.contains("5 in effect"))
    #expect(
      origin.description.contains(
        "Selection.local.json withholds: swift-foundations/swift-color"
      )
    )
  }
}

extension Institute.Selection.Test.`Edge Case` {
  @Test
  func `Unsupported version empty duplicate and self-contradicting overrides fail closed`() {
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(
        version: 2,
        add: [Institute.Selection.Test.dimension]
      ).validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override().validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(
        add: [Institute.Selection.Test.dimension, Institute.Selection.Test.dimension]
      ).validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(
        remove: [Institute.Selection.Test.color, Institute.Selection.Test.color]
      ).validated()
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(
        add: [Institute.Selection.Test.color],
        remove: [Institute.Selection.Test.color]
      ).validated()
    }
  }

  @Test
  func `A stale override fails rather than degrading to a no-op`() {
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(add: [Institute.Selection.Test.color])
        .applied(to: Institute.Selection.Test.committed)
    }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(remove: [Institute.Selection.Test.dimension])
        .applied(to: Institute.Selection.Test.committed)
    }
  }

  @Test
  func `An override that empties the selection fails, as the committed document would`() {
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.Test.override(remove: [Institute.Selection.Test.color])
        .applied(to: Institute.Selection.Test.committed)
    }
  }

  @Test
  func `A repository the override adds but the inventory lacks is attributed to the override`()
    throws
  {
    let unknown = Institute.Selection.Test.key(
      owner: "swift-foundations",
      name: "swift-unknown"
    )
    let merged = try Institute.Selection.Test.override(add: [unknown])
      .applied(to: Institute.Selection.Test.committed)

    let error = #expect(throws: Institute.Error.self) {
      _ = try merged.resolved(
        in: Institute.Selection.Test.inventory,
        origin: .overridden(committed: 1, added: [unknown], removed: [])
      )
    }

    let message = Swift.String(describing: try #require(error))
    #expect(message.contains("Selection.local.json adds repository not present"))
    #expect(!message.contains("Selection.json contains repository not present"))
  }

  @Test
  func `Malformed overrides fail decoding rather than loading as partial deltas`() {
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection.Override(
        jsonString: """
          {
            "version": 1,
            "add": ["swift-primitives/swift-dimension-primitives"]
          }
          """
      )
    }
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection.Override(
        jsonString: """
          {
            "version": 1,
            "add": [],
            "remove": [],
            "repositories": ["swift-foundations/swift-color"]
          }
          """
      )
    }
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Selection.Override(
        jsonString: """
          {
            "version": 1,
            "add": ["swift-foundations/swift-color"],
            "add": ["swift-primitives/swift-dimension-primitives"],
            "remove": []
          }
          """
      )
    }
  }
}

extension Institute.Selection.Test.Integration {
  @Test
  func `A checkout without an override reports the committed selection in effect`() throws {
    let checkout = try Institute.Selection.Test.checkout(
      selection: Institute.Selection.Test.committedDocument
    )
    defer { checkout.remove() }

    let resolved = try Institute.Selection.effective(
      at: checkout.root,
      in: Institute.Selection.Test.inventory
    )

    #expect(resolved.repositories.map(\.name) == ["swift-color"])
    #expect(resolved.origin == .committed(count: 1))
  }

  @Test
  func `A checkout with an override reports both documents and the merged checkout`() throws {
    let checkout = try Institute.Selection.Test.checkout(
      selection: Institute.Selection.Test.committedDocument,
      override: """
        {
          "version": 1,
          "add": ["swift-primitives/swift-dimension-primitives"],
          "remove": []
        }
        """
    )
    defer { checkout.remove() }

    let resolved = try Institute.Selection.effective(
      at: checkout.root,
      in: Institute.Selection.Test.inventory
    )

    #expect(resolved.repositories.map(\.name) == ["swift-color", "swift-dimension-primitives"])
    #expect(
      resolved.origin
        == .overridden(
          committed: 1,
          added: [Institute.Selection.Test.dimension],
          removed: []
        )
    )
  }

  @Test
  func `A malformed override fails the command rather than falling back to committed policy`()
    throws
  {
    let checkout = try Institute.Selection.Test.checkout(
      selection: Institute.Selection.Test.committedDocument,
      override: "{"
    )
    defer { checkout.remove() }

    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.effective(
        at: checkout.root,
        in: Institute.Selection.Test.inventory
      )
    }
  }

  @Test
  func `An override cannot rescue a missing or malformed committed selection`() throws {
    let complete = """
      {
        "version": 1,
        "add": ["swift-primitives/swift-dimension-primitives"],
        "remove": []
      }
      """

    let absent = try Institute.Selection.Test.checkout(selection: nil, override: complete)
    defer { absent.remove() }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.effective(
        at: absent.root,
        in: Institute.Selection.Test.inventory
      )
    }

    let malformed = try Institute.Selection.Test.checkout(selection: "{", override: complete)
    defer { malformed.remove() }
    #expect(throws: Institute.Error.self) {
      _ = try Institute.Selection.effective(
        at: malformed.root,
        in: Institute.Selection.Test.inventory
      )
    }
  }
}
