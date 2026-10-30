public import Institute_Model

extension Institute.Repository.Policy.Manifest {
    public enum Error: Swift.Error, Sendable, Equatable {
        case unreadableRoot(String)
    }
}
