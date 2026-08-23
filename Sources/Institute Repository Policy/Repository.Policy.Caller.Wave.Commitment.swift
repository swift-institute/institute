extension Repository.Policy.Caller.Wave {
    public struct Commitment: Codable, Sendable, Equatable {
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
