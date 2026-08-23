public import Institute_Model

extension Institute.Repository.Policy.BrokenSymlink {
    public enum Error: Swift.Error, Sendable, Equatable {
        case unreadableRoot(String)
        case unreadablePath(String)
    }
}
