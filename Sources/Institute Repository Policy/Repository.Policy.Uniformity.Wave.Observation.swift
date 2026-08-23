extension Repository.Policy.Uniformity.Wave {
    public struct Observation: Codable, Sendable, Equatable {
        public let repository: String
        public let head: String
        public let gitignore: String?
        public let digest: String?
        public let matches: Bool

        public init(
            repository: String,
            head: String,
            gitignore: String?,
            digest: String?,
            matches: Bool
        ) {
            self.repository = repository
            self.head = head
            self.gitignore = gitignore
            self.digest = digest
            self.matches = matches
        }
    }
}
