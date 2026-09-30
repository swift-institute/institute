extension Source.Measurement.Verdict: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    switch value {
    case .clean: ["state": "clean".json]
    case .findings(let findings):
      ["state": "findings".json, "findings": findings.json]
    case .unmeasured(let reasons):
      ["state": "unmeasured".json, "reasons": reasons.json]
    case .notRequested: ["state": "not-requested".json]
    }
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "object", got: "non-object")
    }
    guard let state = object["state"] else { throw .missingKey("state") }
    switch try Swift.String(json: state) {
    case "clean":
      guard Set(object.keys) == ["state"] else {
        throw .typeMismatch(expected: "clean verdict keys", got: "foreign keys")
      }
      return .clean
    case "findings":
      guard Set(object.keys) == ["state", "findings"] else {
        throw .typeMismatch(expected: "findings verdict keys", got: "foreign keys")
      }
      guard let findings = object["findings"] else { throw .missingKey("findings") }
      let decoded = try [Source.Finding](json: findings)
      guard !decoded.isEmpty else {
        throw .typeMismatch(expected: "nonempty findings", got: "empty")
      }
      return .findings(decoded)
    case "unmeasured":
      guard Set(object.keys) == ["state", "reasons"] else {
        throw .typeMismatch(expected: "unmeasured verdict keys", got: "foreign keys")
      }
      guard let reasons = object["reasons"] else { throw .missingKey("reasons") }
      let decoded = try [Source.Reason](json: reasons)
      guard !decoded.isEmpty else {
        throw .typeMismatch(expected: "nonempty reasons", got: "empty")
      }
      return .unmeasured(decoded)
    case "not-requested":
      guard Set(object.keys) == ["state"] else {
        throw .typeMismatch(expected: "not-requested verdict keys", got: "foreign keys")
      }
      return .notRequested
    default: throw .typeMismatch(expected: "measurement verdict", got: "unknown")
    }
  }
}
