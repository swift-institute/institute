public import Institute_Model
public import JSON
public import Source_Profile

extension Institute.Source {
  public struct Preparation: Sendable, JSON.Serializable {
    public static let schema = 3

    public let policyRevision: Swift.String
    public let workspaceDigest: Swift.String
    public let swiftFormatExecutable: Swift.String
    public let swiftFormatTool: Source_Profile.Source.Profile.Digest
    public let linterExecutable: Swift.String
    public let linterTool: Source_Profile.Source.Profile.Digest
    public let directory: Swift.String
    public let profiles: [Swift.String: Source_Profile.Source.Profile.Digest]
    public let verifiedProfiles: [Swift.String]

    public init(
      policyRevision: Swift.String,
      workspaceDigest: Swift.String,
      swiftFormatExecutable: Swift.String,
      swiftFormatTool: Source_Profile.Source.Profile.Digest,
      linterExecutable: Swift.String,
      linterTool: Source_Profile.Source.Profile.Digest,
      directory: Swift.String,
      profiles: [Swift.String: Source_Profile.Source.Profile.Digest],
      verifiedProfiles: [Swift.String]
    ) {
      self.policyRevision = policyRevision
      self.workspaceDigest = workspaceDigest
      self.swiftFormatExecutable = swiftFormatExecutable
      self.swiftFormatTool = swiftFormatTool
      self.linterExecutable = linterExecutable
      self.linterTool = linterTool
      self.directory = directory
      self.profiles = profiles
      self.verifiedProfiles = verifiedProfiles
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "schema": schema.json,
        "policyRevision": value.policyRevision.json,
        "workspaceDigest": value.workspaceDigest.json,
        "swiftFormatExecutable": value.swiftFormatExecutable.json,
        "swiftFormatTool": value.swiftFormatTool.json,
        "linterExecutable": value.linterExecutable.json,
        "linterTool": value.linterTool.json,
        "directory": value.directory.json,
        "profiles": value.profiles.json,
        "verifiedProfiles": value.verifiedProfiles.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "schema", "policyRevision", "workspaceDigest",
        "swiftFormatExecutable", "swiftFormatTool",
        "linterExecutable", "linterTool", "directory", "profiles",
        "verifiedProfiles",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: expected.sorted().joined(separator: ","),
          got: object.keys.sorted().joined(separator: ","))
      }
      guard let schema = object["schema"], try Swift.Int(json: schema) == Self.schema else {
        throw .typeMismatch(expected: "source preparation schema 3", got: "other schema")
      }
      guard let policyRevision = object["policyRevision"],
        let workspaceDigest = object["workspaceDigest"],
        let swiftFormatExecutable = object["swiftFormatExecutable"],
        let swiftFormatTool = object["swiftFormatTool"],
        let linterExecutable = object["linterExecutable"],
        let linterTool = object["linterTool"], let directory = object["directory"],
        let profiles = object["profiles"],
        let verifiedProfiles = object["verifiedProfiles"]
      else { throw .missingKey("source preparation field") }
      return try .init(
        policyRevision: Swift.String(json: policyRevision),
        workspaceDigest: Swift.String(json: workspaceDigest),
        swiftFormatExecutable: Swift.String(json: swiftFormatExecutable),
        swiftFormatTool: Source_Profile.Source.Profile.Digest(json: swiftFormatTool),
        linterExecutable: Swift.String(json: linterExecutable),
        linterTool: Source_Profile.Source.Profile.Digest(json: linterTool),
        directory: Swift.String(json: directory),
        profiles: [Swift.String: Source_Profile.Source.Profile.Digest](json: profiles),
        verifiedProfiles: [Swift.String](json: verifiedProfiles)
      )
    }
  }
}
