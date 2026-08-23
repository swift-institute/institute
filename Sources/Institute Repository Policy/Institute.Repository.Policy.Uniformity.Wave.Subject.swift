public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Subject: Sendable, Equatable {
        public let repository: String
        public let repositoryID: Int64
        public let head: String
        public let manifest: Manifest
        public let shape: Shape

        public init(
            repository: String,
            repositoryID: Int64,
            head: String,
            manifest: Manifest,
            shape: Shape
        ) {
            self.repository = repository
            self.repositoryID = repositoryID
            self.head = head
            self.manifest = manifest
            self.shape = shape
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Subject: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "repositoryID": value.repositoryID.json,
            "head": value.head.json,
            "manifest": value.manifest.json,
            "shape": value.shape.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            repositoryID: try Swift.Int64(json: json["repositoryID"]),
            head: try Swift.String(json: json["head"]),
            manifest: try Institute.Repository.Policy.Caller.Wave.Manifest(json: json["manifest"]),
            shape: try Institute.Repository.Policy.Uniformity.Wave.Shape(json: json["shape"])
        )
    }
}
