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

extension Institute.Navigation {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Institute.Navigation.Test {
  private static func fixture<Result>(
    _ body: (Institute.Navigation, Institute.Repository, Institute.Repository) throws -> Result
  ) throws -> Result {
    let base = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appending(path: "entry with space")
    let checkoutURL =
      base
      .appending(path: "swift-institute")
      .appending(path: "Institute")
    defer {
      try? FileManager.default.removeItem(
        at: base.deletingLastPathComponent()
      )
    }
    try FileManager.default.createDirectory(
      at: checkoutURL,
      withIntermediateDirectories: true
    )

    let checkout = try File.Directory(validating: checkoutURL.path)
    try checkout[file: "Package.swift"].write.atomic(
      "// fixture\n"
    )
    let root = try Institute.Root(checkout: checkout)
    let present = Institute.Repository(
      name: "swift-present",
      url: "https://github.com/swift-primitives/swift-present.git",
      organization: "swift-primitives",
      layer: .primitives
    )
    let absent = Institute.Repository(
      name: "swift-absent",
      url: "https://github.com/swift-foundations/swift-absent.git",
      organization: "swift-foundations",
      layer: .foundations
    )
    let materialized = try root.materialization(for: present)
    try materialized.create.recursive()
    try materialized[file: "Package.swift"].write.atomic("// fixture\n")

    let configuration = Institute.Configuration(
      version: 1,
      scope: "public",
      swift: "Swift version 6.3.3",
      xcode: "26.6",
      repositories: [present, absent]
    )
    return try body(
      Institute.Navigation(root: root, configuration: configuration),
      present,
      absent
    )
  }
}

extension Institute.Navigation.Test.Unit {
  @Test
  func `package roots come from the checkout and materialized inventory only`() throws {
    try Institute.Navigation.Test.fixture { navigation, present, absent in
      let roots = try navigation.packageRoots().map(\.description)

      #expect(roots.count == 2)
      #expect(roots.contains(navigation.root.checkout.description))
      #expect(
        roots.contains(
          try navigation.root.materialization(for: present).description
        )
      )
      #expect(
        !roots.contains(
          try navigation.root.materialization(for: absent).description
        )
      )
    }
  }

  @Test
  func `configuration delegates SourceKit launch to Institute with physical paths`() throws {
    try Institute.Navigation.Test.fixture { navigation, _, _ in
      let rendered = try navigation.renderedConfiguration()
      let document = try JSON.parse(rendered)
      let servers = try #require(document.dictionary?["servers"]?.array)
      let first = try #require(servers.first?.dictionary)
      let command = try #require(first["command"]?.array).map(Swift.String.init)

      #expect(servers.count == 2)
      #expect(command.first == navigation.workspaceExecutable.description)
      #expect(
        command.dropFirst() == [
          "navigation",
          "serve",
          "--workspace-path",
          navigation.root.checkout.description,
        ]
      )
      #expect(rendered.contains("entry with space"))
    }
  }

  @Test
  func `MCP descriptor points at the pinned build and generated configuration`() throws {
    try Institute.Navigation.Test.fixture { navigation, _, _ in
      let document = try JSON.parse(navigation.renderedDescriptor())
      let object = try #require(document.dictionary)
      let arguments = try #require(object["args"]?.array).map(Swift.String.init)
      let environment = try #require(object["env"]?.dictionary)

      #expect(arguments == [navigation.executable.description])
      #expect(Swift.String(object["command"]) == "node")
      #expect(
        Swift.String(environment["CCLSP_CONFIG_PATH"])
          == navigation.configurationFile.description
      )
      #expect(navigation.source.description.contains(Institute.Navigation.revision))
    }
  }
}
