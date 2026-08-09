public import Institute_Model

extension Institute.Inventory {
    /// The committed name → organization → materialized-path register.
    ///
    /// This is a view of the already loaded ``Institute/Configuration``.
    /// It performs no discovery and has no write capability.
    public struct Register: Equatable, Sendable {
        public let repositories: [Institute.Repository]

        public init(repositories: [Institute.Repository]) {
            self.repositories = repositories
        }
    }
}

extension Institute.Inventory.Register: CustomStringConvertible {
    public var description: Swift.String {
        (
            [
                "inventory: \(repositories.count) repositories "
                    + "(name → organization → path)"
            ]
            + repositories.map { repository in
                "  \(repository.name) → \(repository.organization) → "
                    + Institute.Layout.reference(for: repository)
            }
        )
        .joined(separator: "\n")
    }
}
