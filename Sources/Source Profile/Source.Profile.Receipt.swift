extension Source.Profile {
    public struct Receipt: Equatable, Sendable, JSON.Serializable {
        public let profile: Digest
        public let tools: [Engine]

        public init(profile: Digest, tools: [Engine]) {
            self.profile = profile
            self.tools = tools.sorted { $0.id.token < $1.id.token }
        }

        public static func serialize(_ value: Self) -> JSON {
            ["profile": value.profile.json, "tools": value.tools.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard Set(object.keys) == ["profile", "tools"] else {
                throw .typeMismatch(expected: "source receipt keys", got: "foreign keys")
            }
            guard let profile = object["profile"] else { throw .missingKey("profile") }
            guard let tools = object["tools"] else { throw .missingKey("tools") }
            return try Self(profile: Digest(json: profile), tools: [Engine](json: tools))
        }
    }
}
