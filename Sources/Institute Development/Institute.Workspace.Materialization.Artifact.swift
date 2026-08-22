public import Institute_Model
public import JSON

extension Institute.Workspace.Materialization {
    public struct Artifact: Sendable, Equatable, JSON.Serializable {
        public let name: Swift.String
        public let path: Swift.String
        public let digest: Swift.String

        public init(name: Swift.String, path: Swift.String, digest: Swift.String) {
            self.name = name
            self.path = path
            self.digest = digest
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "name": value.name.json,
                "path": value.path.json,
                "digest": value.digest.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            try .init(
                name: Swift.String(json: json["name"]),
                path: Swift.String(json: json["path"]),
                digest: Swift.String(json: json["digest"])
            )
        }
    }
}
