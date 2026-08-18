public import Institute_Model

extension Institute.Hierarchy.Registry {
    public enum Error: Swift.Error, Swift.Sendable {
        /// `register` was asked to add an id that is already registered.
        case duplicate(Institute.Hierarchy.ID)

        /// `register` was asked to add a locator that canonically resolves to
        /// the same physical directory as `existing`'s already-registered
        /// locator.
        case collision(
            existing: Institute.Hierarchy.ID,
            requested: Institute.Hierarchy.ID
        )

        /// `resolve`, `status`, or `forget` was asked about an id that is not
        /// registered.
        case notFound(Institute.Hierarchy.ID)

        /// `status` found `id` registered, but its locator no longer resolves
        /// to an existing directory on disk. Fail-closed: this is reported as
        /// a typed failure, never silently treated as valid.
        case missing(Institute.Hierarchy.ID)

        /// The registry ledger itself could not be read, decoded, or written.
        case workspace(Institute.Error)
    }
}

extension Institute.Hierarchy.Registry.Error: Swift.CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .duplicate(let id):
            "hierarchy id \(id) is already registered"

        case .collision(let existing, let requested):
            "hierarchy \(requested) resolves to the same physical root as "
                + "already-registered \(existing)"

        case .notFound(let id):
            "no hierarchy is registered for id \(id)"

        case .missing(let id):
            "hierarchy \(id)'s registered root no longer exists on disk"

        case .workspace(let error):
            "\(error)"
        }
    }
}
