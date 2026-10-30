extension Source.Profile {
    public struct Digest: Hashable, Sendable, JSON.Serializable {
        public let hex: Swift.String

        public init(_ hex: Swift.String) {
            self.hex = hex
        }

        public static func serialize(_ value: Self) -> JSON { value.hex.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            Self(try Swift.String(json: json))
        }
    }
}
