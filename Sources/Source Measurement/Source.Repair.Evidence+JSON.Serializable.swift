extension Source.Repair.Evidence: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    [
      "file": value.file.json,
      "rule": value.rule.json,
      "disposition": value.disposition.json,
    ]
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "repair evidence object", got: "other")
    }
    guard Set(object.keys) == ["file", "rule", "disposition"] else {
      throw .typeMismatch(expected: "repair evidence keys", got: "foreign keys")
    }
    func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
      guard let value = object[key] else { throw .missingKey(key) }
      return value
    }
    return try Self(
      file: Swift.String(json: required("file")),
      rule: Source.Rule.ID(json: required("rule")),
      disposition: Disposition(json: required("disposition"))
    )
  }
}
