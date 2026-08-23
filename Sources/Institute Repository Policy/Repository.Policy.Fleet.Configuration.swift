extension RepositoryPolicy.Fleet {
    /// Effective package-CI policy resolved centrally from authored fleet
    /// desired state. These values never ride the generated leaf caller.
    public struct Configuration: Swift.Sendable, Swift.Equatable {
        public let lintBundle: Swift.String
        public let platforms: Swift.String
        public let embeddedTarget: Swift.String

        public init(
            lintBundle: Swift.String,
            platforms: Swift.String,
            embeddedTarget: Swift.String
        ) {
            self.lintBundle = lintBundle
            self.platforms = platforms
            self.embeddedTarget = embeddedTarget
        }
    }
}
