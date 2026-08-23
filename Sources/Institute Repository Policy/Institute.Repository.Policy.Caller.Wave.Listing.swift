public import Institute_Model

extension Institute.Repository.Policy.Caller.Wave {
    public struct Listing: Sendable, Equatable {
        public let repositories: [Institute.Repository.Policy.Repository]
        public let expected: Int

        public init(repositories: [Institute.Repository.Policy.Repository], expected: Int) {
            self.repositories = repositories
            self.expected = expected
        }
    }
}
