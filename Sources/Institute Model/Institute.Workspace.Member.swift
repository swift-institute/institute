public import JSON

extension Institute.Workspace {
    public struct Member: Sendable, Equatable, JSON.Serializable {
        public let location: Swift.String
        public let role: Role

        public init(location: Swift.String, role: Role) {
            self.location = location
            self.role = role
        }

        public static func serialize(_ value: Self) -> JSON {
            ["location": value.location.json, "role": value.role.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary,
                Set(object.keys) == ["location", "role"],
                let location = object["location"],
                let role = object["role"]
            else {
                throw .typeMismatch(expected: "workspace member", got: "other JSON")
            }
            return try .init(
                location: Swift.String(json: location),
                role: Role(json: role)
            )
        }
    }
}
