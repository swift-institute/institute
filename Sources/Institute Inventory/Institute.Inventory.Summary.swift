public import Institute_Model

extension Institute.Inventory {
    /// What one run found, in counts.
    public struct Summary: Sendable {
        public var repositories = 0
        public var packages = 0
        public var targets = 0
        public var files = 0
        public var types = 0
        public var members = 0
        public var references = 0
        public var resolved = 0
        public var ambiguous = 0
        public var unresolved = 0
        public var failures = 0
    }
}

extension Institute.Inventory.Summary {
    public var description: Swift.String {
        "\(repositories) repositories, \(packages) packages, \(targets) targets, \(files) files, "
            + "\(types) types, \(members) members, \(references) references (aggregated rows: \(resolved) resolved, "
            + "\(ambiguous) of them ambiguous, \(unresolved) unresolved), \(failures) failures"
    }
}
