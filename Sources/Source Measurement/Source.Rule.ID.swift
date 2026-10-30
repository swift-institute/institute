extension Source.Rule {
    public struct ID: Hashable, Sendable, JSON.Serializable {
        public let engine: Source.Engine.ID
        public let token: Swift.String

        public init(engine: Source.Engine.ID, token: Swift.String) {
            self.engine = engine
            self.token = token
        }

        public static func serialize(_ value: Self) -> JSON {
            ["engine": value.engine.json, "token": value.token.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard Set(object.keys) == ["engine", "token"] else {
                throw .typeMismatch(expected: "source rule keys", got: "foreign keys")
            }
            guard let engine = object["engine"] else { throw .missingKey("engine") }
            guard let token = object["token"] else { throw .missingKey("token") }
            return try Self(
                engine: Source.Engine.ID(json: engine),
                token: Swift.String(json: token)
            )
        }
    }
}
