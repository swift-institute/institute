public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Observation: Sendable, Equatable {
        public let repository: String
        public let head: String
        public let blob: String
        public let digest: String
        public let matches: Bool

        public init(
            repository: String,
            head: String,
            blob: String,
            digest: String,
            matches: Bool
        ) {
            self.repository = repository
            self.head = head
            self.blob = blob
            self.digest = digest
            self.matches = matches
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Observation: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "head": value.head.json,
            "blob": value.blob.json,
            "digest": value.digest.json,
            "matches": value.matches.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            head: try Swift.String(json: json["head"]),
            blob: try Swift.String(json: json["blob"]),
            digest: try Swift.String(json: json["digest"]),
            matches: try Swift.Bool(json: json["matches"])
        )
    }
}
