extension Repository.Policy.Caller.Wave {
    public struct Listing: Sendable, Equatable {
        public let repositories: [RepositoryPolicy.Repository]
        public let expected: Int

        public init(repositories: [RepositoryPolicy.Repository], expected: Int) {
            self.repositories = repositories
            self.expected = expected
        }
    }
}
