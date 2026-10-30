extension Source.Report.Commitment {
    public struct Predicate: Equatable, Sendable, JSON.Serializable {
        public let id: Source.Rule.ID
        public let artifactKinds: [Source.Artifact.Kind]

        public init(
            id: Source.Rule.ID,
            artifactKinds: [Source.Artifact.Kind]
        ) {
            self.id = id
            self.artifactKinds = artifactKinds.sorted { $0.rawValue < $1.rawValue }
        }

        public static func serialize(_ value: Self) -> JSON {
            ["id": value.id.json, "artifactKinds": value.artifactKinds.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard Set(object.keys) == ["id", "artifactKinds"] else {
                throw .typeMismatch(expected: "predicate commitment keys", got: "foreign keys")
            }
            guard let id = object["id"] else { throw .missingKey("id") }
            guard let artifactKinds = object["artifactKinds"] else {
                throw .missingKey("artifactKinds")
            }
            return try Self(
                id: Source.Rule.ID(json: id),
                artifactKinds: [Source.Artifact.Kind](json: artifactKinds)
            )
        }
    }
}
