public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Subject: Sendable, Equatable {
        public let repository: String
        public let repositoryID: Int64
        public let head: String
        public let manifest: Manifest
        public let caller: CallerSource

        public init(
            repository: String,
            repositoryID: Int64,
            head: String,
            manifest: Manifest,
            caller: CallerSource
        ) {
            self.repository = repository
            self.repositoryID = repositoryID
            self.head = head
            self.manifest = manifest
            self.caller = caller
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Subject: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "repositoryID": value.repositoryID.json,
            "head": value.head.json,
            "manifest": value.manifest.json,
            "caller": value.caller.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            repositoryID: try Swift.Int64(json: json["repositoryID"]),
            head: try Swift.String(json: json["head"]),
            manifest: try Institute.Repository.Policy.Caller.Wave.Manifest(json: json["manifest"]),
            caller: try Institute.Repository.Policy.Caller.Wave.CallerSource(json: json["caller"])
        )
    }
}
