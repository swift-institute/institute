public import Institute_Inventory
public import Institute_Model

extension Institute.Dependency {
    /// Measurement status for one inventory repository.
    public struct Subject: Equatable, Sendable {
        public let repository: Institute.Repository.Key
        public let reference: Swift.String?
        public let revision: Swift.String?
        public let state: State
        public let reason: Swift.String?

        public init(
            repository: Institute.Repository.Key,
            reference: Swift.String?,
            revision: Swift.String?,
            state: State,
            reason: Swift.String? = nil
        ) {
            self.repository = repository
            self.reference = reference
            self.revision = revision
            self.state = state
            self.reason = reason
        }
    }
}
