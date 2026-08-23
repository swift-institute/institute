public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Manifest: Sendable, Equatable {
        public let kind: String
        public let blob: String

        public init(kind: String, blob: String) {
            self.kind = kind
            self.blob = blob
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Manifest: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "kind": value.kind.json,
            "blob": value.blob.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            kind: try Swift.String(json: json["kind"]),
            blob: try Swift.String(json: json["blob"])
        )
    }
}
