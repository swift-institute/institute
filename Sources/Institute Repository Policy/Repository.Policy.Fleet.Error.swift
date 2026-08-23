extension RepositoryPolicy.Fleet {
    public enum Error: Swift.Error, Swift.Sendable, Swift.Equatable {
        case unreadable
        case invalid
        case malformedRepository(Swift.String)
        case duplicateOrganization(Swift.String)
        case duplicateRepository(Swift.String)
        case inactiveOrganization(Swift.String)
        case invalidLayer(Swift.String)
        case invalidStatus(Swift.String)
    }
}
