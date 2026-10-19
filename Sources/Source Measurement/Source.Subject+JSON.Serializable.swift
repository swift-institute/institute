extension Source.Subject: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "identity": value.identity.json,
            "root": value.root.json,
            "artifacts": value.artifacts.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard Set(object.keys) == ["identity", "root", "artifacts"] else {
            throw .typeMismatch(expected: "source subject keys", got: "foreign keys")
        }
        guard let identity = object["identity"] else { throw .missingKey("identity") }
        guard let root = object["root"] else { throw .missingKey("root") }
        guard let artifacts = object["artifacts"] else { throw .missingKey("artifacts") }
        return try Self(
            identity: Swift.String(json: identity),
            root: Swift.String(json: root),
            artifacts: [Source.Artifact](json: artifacts)
        )
    }
}
