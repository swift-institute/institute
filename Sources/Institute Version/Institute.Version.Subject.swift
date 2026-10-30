public import Institute_Model

extension Institute.Version {
    /// One repository of an organization, as its listing describes it.
    public struct Subject: Swift.Hashable, Swift.Sendable {
        public let repository: Institute.Repository.Coordinate
        public let archived: Swift.Bool
        public let `private`: Swift.Bool

        public init(repository: Institute.Repository.Coordinate, archived: Swift.Bool, private: Swift.Bool) {
            self.repository = repository
            self.archived = archived
            self.private = `private`
        }
    }
}
