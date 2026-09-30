extension Source.Rule.Observation: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    [
      "file": value.file.json,
      "rule": value.rule.json,
      "applicable": value.applicable.json,
      "coverage": value.coverage.json,
    ]
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "observation object", got: "other")
    }
    guard Set(object.keys) == ["file", "rule", "applicable", "coverage"] else {
      throw .typeMismatch(expected: "observation keys", got: "foreign keys")
    }
    func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
      guard let value = object[key] else { throw .missingKey(key) }
      return value
    }
    return try Self(
      file: Swift.String(json: required("file")),
      rule: Source.Rule.ID(json: required("rule")),
      applicable: Swift.Bool(json: required("applicable")),
      coverage: Source.Rule.Coverage(json: required("coverage"))
    )
  }
}
