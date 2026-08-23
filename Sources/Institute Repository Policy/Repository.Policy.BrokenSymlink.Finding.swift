extension RepositoryPolicy.BrokenSymlink {
    public struct Finding: Sendable, Hashable {
        public let path: String

        public init(path: String) {
            self.path = path
        }
    }
}
