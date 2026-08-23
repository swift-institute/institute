extension Repository.Policy.Caller.Wave {
    public struct Observation: Codable, Sendable, Equatable {
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
