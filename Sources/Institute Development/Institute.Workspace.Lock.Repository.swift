public import Institute_Model
public import JSON

extension Institute.Workspace.Lock {
  public struct Repository: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let id: Swift.String
    public let ref: Swift.String
    public let revision: Swift.String

    public init(id: Swift.String, ref: Swift.String, revision: Swift.String) {
      self.id = id
      self.ref = ref
      self.revision = revision
    }

    public static func serialize(_ value: Self) -> JSON {
      ["id": value.id.json, "ref": value.ref.json, "revision": value.revision.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = ["id", "ref", "revision"]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "lock repository keys id, ref, and revision",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        id: Swift.String(json: object["id"]!),
        ref: Swift.String(json: object["ref"]!),
        revision: Swift.String(json: object["revision"]!)
      )
    }
  }
}
