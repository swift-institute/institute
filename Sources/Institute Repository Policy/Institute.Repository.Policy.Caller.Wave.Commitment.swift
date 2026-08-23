public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Commitment: Sendable, Equatable {
        public let repositories: Int
        public let subjects: Int
        public let repositoryDigest: String
        public let subjectDigest: String
        public let stateDigest: String

        public init(
            repositories: Int,
            subjects: Int,
            repositoryDigest: String,
            subjectDigest: String,
            stateDigest: String
        ) {
            self.repositories = repositories
            self.subjects = subjects
            self.repositoryDigest = repositoryDigest
            self.subjectDigest = subjectDigest
            self.stateDigest = stateDigest
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Commitment: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repositories": value.repositories.json,
            "subjects": value.subjects.json,
            "repositoryDigest": value.repositoryDigest.json,
            "subjectDigest": value.subjectDigest.json,
            "stateDigest": value.stateDigest.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repositories: try Swift.Int(json: json["repositories"]),
            subjects: try Swift.Int(json: json["subjects"]),
            repositoryDigest: try Swift.String(json: json["repositoryDigest"]),
            subjectDigest: try Swift.String(json: json["subjectDigest"]),
            stateDigest: try Swift.String(json: json["stateDigest"])
        )
    }
}
