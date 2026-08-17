public import Institute_Model
public import JSON

extension Institute.Workspace.Lock {
  public struct Resolution: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let repository: Swift.String
    public let path: Swift.String
    public let sha256: Swift.String

    public init(repository: Swift.String, path: Swift.String, sha256: Swift.String) {
      self.repository = repository
      self.path = path
      self.sha256 = sha256
    }

    public static func serialize(_ value: Self) -> JSON {
      ["repository": value.repository.json, "path": value.path.json, "sha256": value.sha256.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = ["repository", "path", "sha256"]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "resolution keys repository, path, and sha256",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        repository: Swift.String(json: object["repository"]!),
        path: Swift.String(json: object["path"]!),
        sha256: Swift.String(json: object["sha256"]!)
      )
    }
  }
}
