extension Source.Report.Commitment {
  public struct Rule: Equatable, Sendable, JSON.Serializable {
    public let id: Source.Rule.ID
    public let controls: [Swift.String]

    public init(id: Source.Rule.ID, controls: [Swift.String]) {
      self.id = id
      self.controls = controls.sorted()
    }

    public static func serialize(_ value: Self) -> JSON {
      ["id": value.id.json, "controls": value.controls.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary, Set(object.keys) == ["id", "controls"],
        let id = object["id"], let controls = object["controls"]
      else { throw .typeMismatch(expected: "rule commitment", got: "other") }
      return try .init(
        id: Source.Rule.ID(json: id),
        controls: [Swift.String](json: controls)
      )
    }
  }
}
