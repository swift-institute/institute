public import Institute_Model

extension Institute.Inventory.Private {
    /// The result of one authenticated private-visibility discovery pass —
    /// the private mirror of ``Institute/Inventory/Discovery``, with a third
    /// population `discover(_:)` structurally cannot produce:
    /// ``unmeasured``.
    public struct Discovery: Equatable, Sendable {
        public let repositories: [Institute.Inventory.Repository]
        public let exclusions: [Institute.Inventory.Exclusion]
        public let unmeasured: [Unmeasured]

        public init(
            repositories: [Institute.Inventory.Repository],
            exclusions: [Institute.Inventory.Exclusion],
            unmeasured: [Unmeasured]
        ) {
            self.repositories = repositories
            self.exclusions = exclusions
            self.unmeasured = unmeasured
        }
    }
}
