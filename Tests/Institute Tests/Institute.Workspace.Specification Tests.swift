import JSON
import Testing
@testable import Institute_Model

@testable import Institute_Development

extension Institute.Workspace.Specification {
  @Suite struct Test {
    @Suite struct Unit {}

    static let repositories: [Institute.Workspace.Repository] = [
      .init(
        id: "repotraffic/repotraffic-com-server",
        package: "repotraffic-com-server",
        organization: "repotraffic",
        layer: .applications,
        role: .application,
        remote: "https://github.com/repotraffic/repotraffic-com-server.git"
      ),
      .init(
        id: "swift-institute/institute-application",
        package: "institute-application",
        organization: "swift-institute",
        layer: .applications,
        role: .tooling,
        remote: "https://github.com/swift-institute/institute-application.git"
      ),
    ]

    static func fixture(
      repositories: [Institute.Workspace.Repository] = repositories,
      compositions: [Institute.Workspace.Composition] = []
    ) -> Institute.Workspace.Specification {
      .init(
        name: "RepoTraffic",
        root: "repotraffic/repotraffic-com-server",
        toolchain: .init(swift: "6.4", xcode: "27.0"),
        repositories: repositories,
        compositions: compositions,
        xcode: .init(name: "RepoTraffic", members: repositories.map(\.id)),
        runtime: .init(compose: "Runtime/compose.yaml")
      )
    }
  }
}

extension Institute.Workspace.Specification.Test.Unit {
  @Test
  func `valid RepoTraffic specification round-trips canonically and adapts externally`() throws {
    let specification = try Institute.Workspace.Specification.Test.fixture().validated()
    let encoded = specification.canonical
    let decoded = try Institute.Workspace.Specification(jsonString: encoded).validated()
    #expect(decoded == specification)
    #expect(decoded.canonical == encoded)
    #expect(decoded.digest.count == 64)

    let configuration = try decoded.configuration()
    #expect(configuration.scope == "RepoTraffic")
    #expect(configuration.repositories.map(\.organization).contains("repotraffic"))
  }

  @Test
  func `unknown keys fail strict decoding`() {
    let canonical = Institute.Workspace.Specification.Test.fixture().canonical
    let source = "{\"unknown\":true," + Swift.String(canonical.dropFirst())
    #expect(throws: JSON.Error.self) {
      _ = try Institute.Workspace.Specification(jsonString: source)
    }
  }

  @Test
  func `duplicate repository id fails`() {
    let repository = Institute.Workspace.Specification.Test.repositories[0]
    let specification = Institute.Workspace.Specification.Test.fixture(repositories: [
      repository, repository,
    ])
    #expect(throws: Institute.Error.self) { _ = try specification.validated() }
  }

  @Test
  func `duplicate package identity fails`() {
    let first = Institute.Workspace.Specification.Test.repositories[0]
    let second = Institute.Workspace.Repository(
      id: "repotraffic/other",
      package: first.package,
      organization: "repotraffic",
      layer: .applications,
      role: .domain,
      remote: "https://github.com/repotraffic/other.git"
    )
    let specification = Institute.Workspace.Specification.Test.fixture(repositories: [
      first, second,
    ])
    #expect(throws: Institute.Error.self) { _ = try specification.validated() }
  }

  @Test
  func `unknown composition endpoint and self-composition fail`() {
    let unknown = Institute.Workspace.Specification.Test.fixture(
      compositions: [
        .init(
          consumer: "repotraffic/repotraffic-com-server", dependency: "swift-foundations/missing")
      ]
    )
    #expect(throws: Institute.Error.self) { _ = try unknown.validated() }

    let selfEdge = Institute.Workspace.Specification.Test.fixture(
      compositions: [
        .init(
          consumer: "repotraffic/repotraffic-com-server",
          dependency: "repotraffic/repotraffic-com-server")
      ]
    )
    #expect(throws: Institute.Error.self) { _ = try selfEdge.validated() }
  }

  @Test
  func `cyclic composition graph fails`() {
    let specification = Institute.Workspace.Specification.Test.fixture(
      compositions: [
        .init(
          consumer: "repotraffic/repotraffic-com-server",
          dependency: "swift-institute/institute-application"),
        .init(
          consumer: "swift-institute/institute-application",
          dependency: "repotraffic/repotraffic-com-server"),
      ]
    )
    #expect(throws: Institute.Error.self) { _ = try specification.validated() }
  }

  @Test
  func `lock rejects specification mismatch and abbreviated revision`() throws {
    let specification = try Institute.Workspace.Specification.Test.fixture().validated()
    let repositories = specification.repositories.map {
      Institute.Workspace.Lock.Repository(
        id: $0.id, ref: "refs/heads/main", revision: Swift.String(repeating: "a", count: 40))
    }
    let resolution = Institute.Workspace.Lock.Resolution(
      repository: specification.root,
      path: "Package.resolved",
      sha256: Swift.String(repeating: "b", count: 64)
    )
    let valid = Institute.Workspace.Lock(
      specification: specification.digest,
      toolchain: specification.toolchain,
      repositories: repositories,
      resolution: resolution
    )
    _ = try valid.validated(against: specification)

    let mismatched = Institute.Workspace.Lock(
      specification: Swift.String(repeating: "0", count: 64),
      toolchain: specification.toolchain,
      repositories: repositories,
      resolution: resolution
    )
    #expect(throws: Institute.Error.self) { _ = try mismatched.validated(against: specification) }

    let abbreviated = Institute.Workspace.Lock(
      specification: specification.digest,
      toolchain: specification.toolchain,
      repositories: [.init(id: repositories[0].id, ref: "refs/heads/main", revision: "abc")]
        + Array(repositories.dropFirst()),
      resolution: resolution
    )
    #expect(throws: Institute.Error.self) { _ = try abbreviated.validated(against: specification) }
  }
}
