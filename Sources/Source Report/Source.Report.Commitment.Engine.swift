extension Source.Report.Commitment {
  public struct Engine: Equatable, Sendable, JSON.Serializable {
    public let id: Source.Engine.ID
    public let artifactKinds: [Source.Artifact.Kind]
    public let controlPolicy: ControlPolicy

    public init(
      id: Source.Engine.ID,
      artifactKinds: [Source.Artifact.Kind],
      controlPolicy: ControlPolicy = .required
    ) {
      self.id = id
      self.artifactKinds = artifactKinds.sorted { $0.rawValue < $1.rawValue }
      self.controlPolicy = controlPolicy
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "id": value.id.json,
        "artifactKinds": value.artifactKinds.json,
        "controlPolicy": value.controlPolicy.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == ["id", "artifactKinds", "controlPolicy"] else {
        throw .typeMismatch(expected: "engine commitment keys", got: "foreign keys")
      }
      guard let id = object["id"] else { throw .missingKey("id") }
      guard let artifactKinds = object["artifactKinds"] else {
        throw .missingKey("artifactKinds")
      }
      guard let controlPolicy = object["controlPolicy"] else {
        throw .missingKey("controlPolicy")
      }
      return try Self(
        id: Source.Engine.ID(json: id),
        artifactKinds: [Source.Artifact.Kind](json: artifactKinds),
        controlPolicy: ControlPolicy(json: controlPolicy)
      )
    }
  }
}
