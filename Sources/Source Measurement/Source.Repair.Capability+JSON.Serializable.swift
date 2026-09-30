extension Source.Repair.Capability: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    switch value {
    case .automatic: ["state": "automatic".json]
    case .guarded: ["state": "guarded".json]
    case .transactional: ["state": "transactional".json]
    case .unavailable(let reason):
      ["state": "unavailable".json, "reason": reason.json]
    }
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "object", got: "non-object")
    }
    guard let state = object["state"] else { throw .missingKey("state") }
    switch try Swift.String(json: state) {
    case "automatic":
      guard Set(object.keys) == ["state"] else {
        throw .typeMismatch(expected: "automatic repair capability keys", got: "foreign keys")
      }
      return .automatic
    case "guarded":
      guard Set(object.keys) == ["state"] else {
        throw .typeMismatch(expected: "guarded repair capability keys", got: "foreign keys")
      }
      return .guarded
    case "transactional":
      guard Set(object.keys) == ["state"] else {
        throw .typeMismatch(expected: "transactional repair capability keys", got: "foreign keys")
      }
      return .transactional
    case "unavailable":
      guard Set(object.keys) == ["state", "reason"] else {
        throw .typeMismatch(expected: "unavailable repair capability keys", got: "foreign keys")
      }
      guard let reason = object["reason"] else { throw .missingKey("reason") }
      return try .unavailable(Source.Reason(json: reason))
    default: throw .typeMismatch(expected: "repair capability", got: "unknown")
    }
  }
}
