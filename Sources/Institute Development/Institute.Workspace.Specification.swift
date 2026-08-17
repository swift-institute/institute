public import Byte_Primitives
public import FIPS_180_4
public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Specification: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let version: Swift.Int
    public let name: Swift.String
    public let root: Swift.String
    public let toolchain: Toolchain
    public let repositories: [Repository]
    public let compositions: [Composition]
    public let xcode: Xcode
    public let runtime: Runtime

    public init(
      version: Swift.Int = 1,
      name: Swift.String,
      root: Swift.String,
      toolchain: Toolchain,
      repositories: [Repository],
      compositions: [Composition],
      xcode: Xcode,
      runtime: Runtime
    ) {
      self.version = version
      self.name = name
      self.root = root
      self.toolchain = toolchain
      self.repositories = repositories
      self.compositions = compositions
      self.xcode = xcode
      self.runtime = runtime
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "version": value.version.json,
        "name": value.name.json,
        "root": value.root.json,
        "toolchain": value.toolchain.json,
        "repositories": value.repositories.json,
        "compositions": value.compositions.json,
        "xcode": value.xcode.json,
        "runtime": value.runtime.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "version", "name", "root", "toolchain", "repositories", "compositions", "xcode", "runtime",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "workspace specification version 1 keys",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        version: Swift.Int(json: object["version"]!),
        name: Swift.String(json: object["name"]!),
        root: Swift.String(json: object["root"]!),
        toolchain: Toolchain(json: object["toolchain"]!),
        repositories: [Repository](json: object["repositories"]!),
        compositions: [Composition](json: object["compositions"]!),
        xcode: Xcode(json: object["xcode"]!),
        runtime: Runtime(json: object["runtime"]!)
      )
    }
  }
}

extension Institute.Workspace.Specification {
  public func validated() throws(Institute.Error) -> Self {
    guard version == 1 else {
      throw .configuration("Workspace.json version must be 1; found \(version)")
    }
    guard !name.isEmpty else { throw .configuration("Workspace.json name must not be empty") }
    guard !root.isEmpty else { throw .configuration("Workspace.json root must not be empty") }
    guard !toolchain.swift.isEmpty, !toolchain.xcode.isEmpty else {
      throw .configuration("Workspace.json toolchain.swift and toolchain.xcode must not be empty")
    }

    var identifiers = Set<Swift.String>()
    var packages = Set<Swift.String>()
    for repository in repositories {
      guard identifiers.insert(repository.id).inserted else {
        throw .configuration("Workspace.json repositories contains duplicate id \(repository.id)")
      }
      guard packages.insert(repository.package).inserted else {
        throw .configuration(
          "Workspace.json repositories contains duplicate package identity \(repository.package)")
      }
      guard
        repository.id
          == "\(repository.organization)/\(repository.id.split(separator: "/").last ?? "")"
      else {
        throw .configuration(
          "Workspace.json repository \(repository.id) does not match organization \(repository.organization)"
        )
      }
      guard !repository.remote.isEmpty, !repository.remote.hasPrefix("/") else {
        throw .configuration(
          "Workspace.json repository \(repository.id) remote must be a portable canonical URL")
      }
    }
    guard identifiers.contains(root) else {
      throw .configuration("Workspace.json root \(root) is not a declared repository id")
    }

    var edges = Set<Institute.Workspace.Composition>()
    for edge in compositions {
      guard identifiers.contains(edge.consumer) else {
        throw .configuration("Workspace.json composition consumer \(edge.consumer) is not declared")
      }
      guard identifiers.contains(edge.dependency) else {
        throw .configuration(
          "Workspace.json composition dependency \(edge.dependency) is not declared")
      }
      guard edge.consumer != edge.dependency else {
        throw .configuration("Workspace.json composition \(edge.consumer) cannot depend on itself")
      }
      guard edges.insert(edge).inserted else {
        throw .configuration(
          "Workspace.json contains duplicate composition \(edge.consumer) -> \(edge.dependency)")
      }
    }
    for member in xcode.members where !identifiers.contains(member) {
      throw .configuration("Workspace.json xcode member \(member) is not a declared repository id")
    }
    guard Set(xcode.members).count == xcode.members.count else {
      throw .configuration("Workspace.json xcode members contains a duplicate repository id")
    }
    try validateAcyclic(edges: edges, identifiers: identifiers)
    return self
  }

  public var canonical: Swift.String { jsonString(pretty: false, sortKeys: true) }

  public var digest: Swift.String {
    FIPS_180_4.SHA256.digest(Array(canonical.utf8).map(Byte.init)).hex
  }

  public func configuration() throws(Institute.Error) -> Institute.Configuration {
    let specification = try validated()
    return Institute.Configuration(
      version: 1,
      scope: specification.name,
      swift: specification.toolchain.swift,
      xcode: specification.toolchain.xcode,
      repositories: specification.repositories.map {
        Institute.Repository(
          name: $0.package, url: $0.remote, organization: $0.organization, layer: $0.layer)
      }
    )
  }

  private func validateAcyclic(
    edges: Set<Institute.Workspace.Composition>,
    identifiers: Set<Swift.String>
  ) throws(Institute.Error) {
    var visiting = Set<Swift.String>()
    var visited = Set<Swift.String>()
    let graph = Dictionary(grouping: edges, by: \.consumer)

    func visit(_ identifier: Swift.String) throws(Institute.Error) {
      if visiting.contains(identifier) {
        throw .configuration("Workspace.json composition graph contains a cycle at \(identifier)")
      }
      guard !visited.contains(identifier) else { return }
      visiting.insert(identifier)
      for edge in graph[identifier, default: []] { try visit(edge.dependency) }
      visiting.remove(identifier)
      visited.insert(identifier)
    }

    for identifier in identifiers.sorted() { try visit(identifier) }
  }
}
