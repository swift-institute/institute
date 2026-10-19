extension Source.Artifact {
    public struct Schema: Hashable, Sendable, JSON.Serializable {
        public let token: Swift.String

        public init(_ token: Swift.String) {
            self.token = token
        }
    }
}

extension Source.Artifact.Schema {
    public static func serialize(_ value: Self) -> JSON { value.token.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        .init(try Swift.String(json: json))
    }
}
