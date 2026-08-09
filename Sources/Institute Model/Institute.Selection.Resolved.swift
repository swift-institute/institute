extension Institute.Selection {
    public struct Resolved: Equatable, Sendable {
        public let repositories: [Institute.Repository]

        /// How this selection was formed. It travels with the resolved
        /// repositories rather than beside them so no consumer can hold
        /// the effective set without being able to say where it came from.
        public let origin: Institute.Selection.Origin

        package init(
            repositories: [Institute.Repository],
            origin: Institute.Selection.Origin
        ) {
            self.repositories = repositories
            self.origin = origin
        }
    }
}
