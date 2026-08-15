public import Institute_Model

extension Institute.Inventory {
    public struct Exclusion: Equatable, Sendable {
        public let repository: Institute.Repository.Key
        public let reason: Eligibility.Reason

        public init(repository: Institute.Repository.Key, reason: Eligibility.Reason) {
            self.repository = repository
            self.reason = reason
        }
    }
}
