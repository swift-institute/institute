public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Repository: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let id: Swift.String
    public let package: Swift.String
    public let organization: Swift.String
    public let layer: Institute.Layer
    public let role: Role
    public let remote: Swift.String

    public init(
      id: Swift.String,
      package: Swift.String,
      organization: Swift.String,
      layer: Institute.Layer,
      role: Role,
      remote: Swift.String
    ) {
      self.id = id
      self.package = package
      self.organization = organization
      self.layer = layer
      self.role = role
      self.remote = remote
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "id": value.id.json,
        "package": value.package.json,
        "organization": value.organization.json,
        "layer": value.layer.json,
        "role": value.role.json,
        "remote": value.remote.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      let object = try Self.object(
        json, keys: ["id", "package", "organization", "layer", "role", "remote"])
      return try Self(
        id: Swift.String(json: object["id"]!),
        package: Swift.String(json: object["package"]!),
        organization: Swift.String(json: object["organization"]!),
        layer: Institute.Layer(json: object["layer"]!),
        role: Role(json: object["role"]!),
        remote: Swift.String(json: object["remote"]!)
      )
    }

    private static func object(_ json: JSON, keys: Set<Swift.String>) throws(JSON.Error) -> [Swift
      .String: JSON]
    {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == keys else {
        throw .typeMismatch(
          expected: keys.sorted().joined(separator: ", "),
          got: object.keys.sorted().joined(separator: ", "))
      }
      return object
    }
  }
}
