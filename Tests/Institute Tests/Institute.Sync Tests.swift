import File_System
import Foundation
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

extension Institute.Sync {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Institute.Sync.Test.Integration {
  private static func selectedAuthority(
    _ fixture: Institute.Sync.Fixture
  ) throws -> Institute.Sync {
    let repository = Institute.Repository(
      name: "swift-rfc-0000",
      url: fixture.remote.path,
      organization: "swift-ietf",
      layer: .standards
    )
    return Institute.Sync(
      root: try Institute.Root(checkout: File.Directory(validating: fixture.root.path)),
      selection: .init(repositories: [repository], origin: .committed(count: 1)),
      client: fixture.client
    )
  }

  @Test
  func `Dry run changes neither canonical checkout metadata nor checkout owned files`() throws {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    try fixture.push("second", contents: "second\n")
    let before = try fixture.state()

    try fixture.application().run(dry: true)

    #expect(try fixture.state() == before)
    #expect(try fixture.residue().isEmpty)
  }

  @Test
  func
    `Force pushed remote leaves local repository untouched while publishing the checkout workspace`()
    throws
  {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    try fixture.replaceRemote()
    let before = try fixture.state()

    try fixture.application().run(dry: false)

    let after = try fixture.state()
    #expect(after.head == before.head)
    #expect(after.origin == before.origin)
    #expect(after.fetch == before.fetch)
    #expect(after.status == before.status)
    #expect(after.canonical == before.canonical)
    #expect(after.legacy == before.legacy)
    #expect(after.ledger == before.ledger)
    #expect(after.workspace != nil)
    #expect(try fixture.residue().isEmpty)
  }

  @Test
  func `a regular directory at the canonical target stops sync before workspace publication`()
    throws
  {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    let collision = fixture.base.appending(path: "swift-standards/swift-ietf/swift-rfc-0000")
    try FileManager.default.createDirectory(at: collision, withIntermediateDirectories: true)
    let marker = collision.appending(path: "marker")
    try Data("collision".utf8).write(to: marker)

    #expect(throws: Institute.Error.self) {
      try Self.selectedAuthority(fixture).run(dry: false)
    }

    #expect(try Data(contentsOf: marker) == Data("collision".utf8))
    #expect(
      !FileManager.default.fileExists(
        atPath: fixture.root.appending(path: "institute.xcworkspace").path
      )
    )
  }

  @Test
  func `a symbolic sibling prefix stops sync without writing through the link`() throws {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    let outside = fixture.base.appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: fixture.base.appending(path: "swift-standards"),
      withDestinationURL: outside
    )

    #expect(throws: Institute.Error.self) {
      try Self.selectedAuthority(fixture).run(dry: false)
    }

    #expect(
      !FileManager.default.fileExists(
        atPath: outside.appending(path: "swift-ietf/swift-rfc-0000").path
      )
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: fixture.root.appending(path: "institute.xcworkspace").path
      )
    )
  }

  @Test
  func `A resolved selection clones only its authority repository and renders only that reference`()
    throws
  {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    let selected = Institute.Repository(
      name: "swift-rfc-0000",
      url: fixture.remote.path,
      organization: "swift-ietf",
      layer: .standards
    )
    let unselected = Institute.Repository(
      name: "swift-unused",
      url: "https://github.com/swift-foundations/swift-unused.git",
      organization: "swift-foundations",
      layer: .foundations
    )
    let root = try File.Directory(validating: fixture.root.path)
    let sync = Institute.Sync(
      root: try Institute.Root(checkout: root),
      selection: .init(repositories: [selected], origin: .committed(count: 1)),
      client: fixture.client
    )

    try sync.run(dry: false)

    let cloned = fixture.base.appending(
      path: "swift-standards/swift-ietf/swift-rfc-0000/.git"
    )
    #expect(FileManager.default.fileExists(atPath: cloned.path))
    let excluded = fixture.base.appending(
      path: Institute.Layout.reference(for: unselected)
    )
    #expect(!FileManager.default.fileExists(atPath: excluded.path))
    let workspace = try #require(Institute.Xcode.contents(at: root))
    #expect(workspace.contains("../\(Institute.Layout.reference(for: selected))"))
    #expect(!workspace.contains("../\(Institute.Layout.reference(for: unselected))"))
    #expect(
      !FileManager.default.fileExists(
        atPath: fixture.root.appending(path: Institute.Layout.reference(for: selected)).path
      )
    )
  }

  @Test
  func `Proven descendant fast forwards local main`() throws {
    let fixture = try Institute.Sync.Fixture()
    defer { fixture.remove() }
    try fixture.push("second", contents: "second\n")
    let before = try fixture.state()

    try fixture.application().run(dry: false)

    let after = try fixture.state()
    #expect(after.head != before.head)
    #expect(after.head == after.origin)
    #expect(after.status.isEmpty)
    #expect(try fixture.residue().isEmpty)
  }
}
