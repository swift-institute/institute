extension RepositoryPolicy {
    /// Authored fleet membership decoded from the control-plane policy document.
    public struct Fleet: Swift.Decodable, Swift.Sendable, Swift.Equatable {
        public let schemaVersion: Swift.Int
        public let organizations: [Organization]
        public let repositories: [Repository]?

        public var activeOrganizationNames: Swift.Set<Swift.String> {
            Swift.Set(organizations.lazy.filter { $0.status == "active" }.map(\.name))
        }
    }
}
