extension Repository.Policy.Caller.Wave {
    public struct Subject: Codable, Sendable, Equatable {
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
