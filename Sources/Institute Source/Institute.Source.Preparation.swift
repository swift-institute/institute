public import Institute_Model
public import JSON
public import Source_Profile

extension Institute.Source {
  public struct Preparation: Sendable, JSON.Serializable {
    public static let schema = 4

    public let policyRevision: Swift.String
    public let workspaceDigest: Swift.String
    public let swiftFormatExecutable: Swift.String
    public let swiftFormatTool: Source_Profile.Source.Profile.Digest
    public let linterExecutable: Swift.String
    public let linter: Linter
    public let directory: Swift.String
    public let profiles: [Swift.String: Source_Profile.Source.Profile.Digest]
    public let verifiedProfiles: [Swift.String]

    public init(
      policyRevision: Swift.String,
      workspaceDigest: Swift.String,
      swiftFormatExecutable: Swift.String,
      swiftFormatTool: Source_Profile.Source.Profile.Digest,
      linterExecutable: Swift.String,
      linter: Linter,
      directory: Swift.String,
      profiles: [Swift.String: Source_Profile.Source.Profile.Digest],
      verifiedProfiles: [Swift.String]
    ) {
      self.policyRevision = policyRevision
      self.workspaceDigest = workspaceDigest
      self.swiftFormatExecutable = swiftFormatExecutable
      self.swiftFormatTool = swiftFormatTool
      self.linterExecutable = linterExecutable
      self.linter = linter
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
        "linter": value.linter.json,
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
        "linterExecutable", "linter", "directory", "profiles",
        "verifiedProfiles",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: expected.sorted().joined(separator: ","),
          got: object.keys.sorted().joined(separator: ","))
      }
      guard let schema = object["schema"], try Swift.Int(json: schema) == Self.schema else {
        throw .typeMismatch(expected: "source preparation schema 4", got: "other schema")
      }
      guard let policyRevision = object["policyRevision"],
        let workspaceDigest = object["workspaceDigest"],
        let swiftFormatExecutable = object["swiftFormatExecutable"],
        let swiftFormatTool = object["swiftFormatTool"],
        let linterExecutable = object["linterExecutable"],
        let linter = object["linter"], let directory = object["directory"],
        let profiles = object["profiles"],
        let verifiedProfiles = object["verifiedProfiles"]
      else { throw .missingKey("source preparation field") }
      return try .init(
        policyRevision: Swift.String(json: policyRevision),
        workspaceDigest: Swift.String(json: workspaceDigest),
        swiftFormatExecutable: Swift.String(json: swiftFormatExecutable),
        swiftFormatTool: Source_Profile.Source.Profile.Digest(json: swiftFormatTool),
        linterExecutable: Swift.String(json: linterExecutable),
        linter: Linter(json: linter),
        directory: Swift.String(json: directory),
        profiles: [Swift.String: Source_Profile.Source.Profile.Digest](json: profiles),
        verifiedProfiles: [Swift.String](json: verifiedProfiles)
      )
    }
  }
}

extension Institute.Source.Preparation {
  public var linterTool: Source_Profile.Source.Profile.Digest { linter.digest }

  public struct Linter: Sendable, JSON.Serializable {
    public let origin: Origin
    public let digest: Source_Profile.Source.Profile.Digest

    public init(
      origin: Origin,
      digest: Source_Profile.Source.Profile.Digest
    ) {
      self.origin = origin
      self.digest = digest
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "origin": value.origin.json,
        "digest": value.digest.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == ["origin", "digest"] else {
        throw .typeMismatch(expected: "source linter binding keys", got: "foreign keys")
      }
      guard let origin = object["origin"] else { throw .missingKey("origin") }
      guard let digest = object["digest"] else { throw .missingKey("digest") }
      return try .init(
        origin: Origin(json: origin),
        digest: Source_Profile.Source.Profile.Digest(json: digest)
      )
    }
  }
}

extension Institute.Source.Preparation.Linter {
  public enum Origin: Sendable, Equatable, JSON.Serializable {
    case published(asset: Swift.String)
    case local

    public static func serialize(_ value: Self) -> JSON {
      switch value {
      case .published(let asset):
        ["kind": "published".json, "asset": asset.json]
      case .local:
        ["kind": "local".json]
      }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary, let kind = object["kind"] else {
        throw .typeMismatch(expected: "source linter origin", got: "other")
      }
      switch try Swift.String(json: kind) {
      case "published":
        guard Set(object.keys) == ["kind", "asset"], let asset = object["asset"] else {
          throw .typeMismatch(expected: "published source linter origin", got: "other")
        }
        return try .published(asset: Swift.String(json: asset))
      case "local":
        guard Set(object.keys) == ["kind"] else {
          throw .typeMismatch(expected: "local source linter origin", got: "other")
        }
        return .local
      default:
        throw .typeMismatch(expected: "published or local source linter origin", got: "other")
      }
    }
  }
}
