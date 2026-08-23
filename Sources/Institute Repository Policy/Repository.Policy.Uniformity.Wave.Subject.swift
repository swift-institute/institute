extension Repository.Policy.Uniformity.Wave {
    public struct Subject: Codable, Sendable, Equatable {
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
