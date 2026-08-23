public import Institute_Model
public import JSON
public import Source_Profile

extension Institute.Source {
  public struct Preparation: Sendable, JSON.Serializable {
    public static let schema = 2

    public let policyRevision: Swift.String
    public let swiftFormatExecutable: Swift.String
    public let swiftFormatTool: Source_Profile.Source.Profile.Digest
    public let swiftLintExecutable: Swift.String
    public let swiftLintTool: Source_Profile.Source.Profile.Digest
    public let swiftLintRules: [Source_Profile.Source.Rule.ID]
    public let linterExecutable: Swift.String
    public let linterTool: Source_Profile.Source.Profile.Digest
    public let directory: Swift.String
    public let profiles: [Swift.String: Source_Profile.Source.Profile.Digest]

    public static func serialize(_ value: Self) -> JSON {
      [
        "schema": schema.json,
        "policyRevision": value.policyRevision.json,
        "swiftFormatExecutable": value.swiftFormatExecutable.json,
        "swiftFormatTool": value.swiftFormatTool.json,
        "swiftLintExecutable": value.swiftLintExecutable.json,
        "swiftLintTool": value.swiftLintTool.json,
        "swiftLintRules": value.swiftLintRules.json,
        "linterExecutable": value.linterExecutable.json,
        "linterTool": value.linterTool.json,
        "directory": value.directory.json,
        "profiles": value.profiles.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "schema", "policyRevision", "swiftFormatExecutable", "swiftFormatTool",
        "swiftLintExecutable", "swiftLintTool", "swiftLintRules",
        "linterExecutable", "linterTool", "directory", "profiles",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: expected.sorted().joined(separator: ","),
          got: object.keys.sorted().joined(separator: ","))
      }
      guard let schema = object["schema"], try Swift.Int(json: schema) == Self.schema else {
        throw .typeMismatch(expected: "source preparation schema 2", got: "other schema")
      }
      guard let policyRevision = object["policyRevision"],
        let swiftFormatExecutable = object["swiftFormatExecutable"],
        let swiftFormatTool = object["swiftFormatTool"],
        let swiftLintExecutable = object["swiftLintExecutable"],
        let swiftLintTool = object["swiftLintTool"],
        let swiftLintRules = object["swiftLintRules"],
        let linterExecutable = object["linterExecutable"],
        let linterTool = object["linterTool"], let directory = object["directory"],
        let profiles = object["profiles"]
      else { throw .missingKey("source preparation field") }
      return try .init(
        policyRevision: Swift.String(json: policyRevision),
        swiftFormatExecutable: Swift.String(json: swiftFormatExecutable),
        swiftFormatTool: Source_Profile.Source.Profile.Digest(json: swiftFormatTool),
        swiftLintExecutable: Swift.String(json: swiftLintExecutable),
        swiftLintTool: Source_Profile.Source.Profile.Digest(json: swiftLintTool),
        swiftLintRules: [Source_Profile.Source.Rule.ID](json: swiftLintRules),
        linterExecutable: Swift.String(json: linterExecutable),
        linterTool: Source_Profile.Source.Profile.Digest(json: linterTool),
        directory: Swift.String(json: directory),
        profiles: [Swift.String: Source_Profile.Source.Profile.Digest](json: profiles)
      )
    }
  }
}
