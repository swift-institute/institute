extension Source.Subject {
    public struct Binding: Hashable, Sendable {
        public let identity: Swift.String
        public let digest: Swift.String

        public init(identity: Swift.String, digest: Swift.String) {
            self.identity = identity
            self.digest = digest
        }
    }
}

extension Source.Subject.Binding: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        ["identity": value.identity.json, "digest": value.digest.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard Set(object.keys) == ["identity", "digest"] else {
            throw .typeMismatch(expected: "source subject binding keys", got: "foreign keys")
        }
        guard let identity = object["identity"] else { throw .missingKey("identity") }
        guard let digest = object["digest"] else { throw .missingKey("digest") }
        return try Self(
            identity: Swift.String(json: identity),
            digest: Swift.String(json: digest)
        )
    }
}
