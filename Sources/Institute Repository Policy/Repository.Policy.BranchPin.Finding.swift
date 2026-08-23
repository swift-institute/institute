extension RepositoryPolicy.BranchPin {
    public struct Finding: Swift.Sendable, Swift.Hashable {
        public let document: Swift.String
        public let url: Swift.String
        public let branch: Swift.String

        public init(document: Swift.String, url: Swift.String, branch: Swift.String) {
            self.document = document
            self.url = url
            self.branch = branch
        }
    }
}
