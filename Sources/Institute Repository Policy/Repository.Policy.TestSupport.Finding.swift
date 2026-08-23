extension RepositoryPolicy.TestSupport {
    public struct Finding: Sendable, Equatable {
        public let target: Swift.String
        public let dependency: Swift.String

        public init(target: Swift.String, dependency: Swift.String) {
            self.target = target
            self.dependency = dependency
        }
    }
}
