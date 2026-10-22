public import Institute_CI_Model
public import Institute_Model

extension Institute.Repository.Policy.Fleet {
    /// Effective package-CI policy resolved centrally from authored fleet
    /// desired state. These values never ride the generated leaf caller.
    public struct Configuration: Swift.Sendable, Swift.Equatable {
        public let lintBundle: Swift.String
        public let platforms: Swift.String
        public let embedded: Institute.CI.Plan.Embedded

        public init(
            lintBundle: Swift.String,
            platforms: Swift.String,
            embedded: Institute.CI.Plan.Embedded
        ) {
            self.lintBundle = lintBundle
            self.platforms = platforms
            self.embedded = embedded
        }
    }
}
