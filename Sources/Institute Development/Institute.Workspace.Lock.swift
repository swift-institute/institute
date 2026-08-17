public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Lock: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let version: Swift.Int
    public let specification: Swift.String
    public let toolchain: Toolchain
    public let repositories: [Repository]
    public let resolution: Resolution

    public init(
      version: Swift.Int = 1,
      specification: Swift.String,
      toolchain: Toolchain,
      repositories: [Repository],
      resolution: Resolution
    ) {
      self.version = version
      self.specification = specification
      self.toolchain = toolchain
      self.repositories = repositories
      self.resolution = resolution
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "version": value.version.json,
        "specification": value.specification.json,
        "toolchain": value.toolchain.json,
        "repositories": value.repositories.json,
        "resolution": value.resolution.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "version", "specification", "toolchain", "repositories", "resolution",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "workspace lock version 1 keys",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        version: Swift.Int(json: object["version"]!),
        specification: Swift.String(json: object["specification"]!),
        toolchain: Toolchain(json: object["toolchain"]!),
        repositories: [Repository](json: object["repositories"]!),
        resolution: Resolution(json: object["resolution"]!)
      )
    }
  }
}

extension Institute.Workspace.Lock {
  public func validated(against specification: Institute.Workspace.Specification) throws(Institute
    .Error) -> Self
  {
    let specification = try specification.validated()
    guard version == 1 else {
      throw .configuration("Workspace.lock.json version must be 1; found \(version)")
    }
    guard self.specification == specification.digest else {
      throw .configuration("Workspace.lock.json specification digest does not match Workspace.json")
    }
    guard toolchain == specification.toolchain else {
      throw .configuration("Workspace.lock.json toolchain does not match Workspace.json")
    }
    var identifiers = Set<Swift.String>()
    let hexadecimal = "0123456789abcdef"
    for repository in repositories {
      guard identifiers.insert(repository.id).inserted else {
        throw .configuration(
          "Workspace.lock.json contains duplicate repository id \(repository.id)")
      }
      guard specification.repositories.contains(where: { $0.id == repository.id }) else {
        throw .configuration(
          "Workspace.lock.json repository \(repository.id) is not declared by Workspace.json")
      }
      guard repository.revision.count == 40,
        repository.revision.allSatisfy(hexadecimal.contains)
      else {
        throw .configuration(
          "Workspace.lock.json repository \(repository.id) revision must be a lowercase 40-character SHA"
        )
      }
      guard repository.ref.hasPrefix("refs/") else {
        throw .configuration(
          "Workspace.lock.json repository \(repository.id) ref must be fully qualified")
      }
    }
    guard Set(specification.repositories.map(\.id)) == identifiers else {
      throw .configuration(
        "Workspace.lock.json must lock every Workspace.json repository exactly once")
    }
    guard resolution.repository == specification.root else {
      throw .configuration(
        "Workspace.lock.json resolution repository must be the workspace root \(specification.root)"
      )
    }
    guard !resolution.path.hasPrefix("/"), resolution.path == "Package.resolved" else {
      throw .configuration("Workspace.lock.json resolution path must be portable Package.resolved")
    }
    guard resolution.sha256.count == 64,
      resolution.sha256.allSatisfy(hexadecimal.contains)
    else {
      throw .configuration(
        "Workspace.lock.json resolution sha256 must be 64 lowercase hexadecimal characters")
    }
    return self
  }
}
