extension Institute {
    public struct Inspection: Sendable {
        public let repository: Repository
        public let action: Action

        public init(repository: Repository, action: Action) {
            self.repository = repository
            self.action = action
        }
    }
}
