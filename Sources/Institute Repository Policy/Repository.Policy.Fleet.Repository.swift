extension RepositoryPolicy.Fleet {
    /// Authored repository-specific policy that cannot be derived from the
    /// repository's owning organization. Absence means the layer defaults.
    public struct Repository: Swift.Decodable, Swift.Sendable, Swift.Equatable {
        public let name: Swift.String
        public let platforms: Swift.String?
        public let embeddedTarget: Swift.String?
    }
}
