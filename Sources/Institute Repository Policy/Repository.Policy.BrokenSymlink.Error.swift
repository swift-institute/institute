extension RepositoryPolicy.BrokenSymlink {
    public enum Error: Swift.Error, Sendable, Equatable {
        case unreadableRoot(String)
        case unreadablePath(String)
    }
}
