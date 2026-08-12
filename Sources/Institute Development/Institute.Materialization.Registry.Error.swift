public import Institute_Model

extension Institute.Materialization.Registry {
  public enum Error: Swift.Error, Swift.Sendable {
    /// `register` was asked to add an id that is already registered.
    case duplicate(Institute.Materialization.ID)

    /// `register` was asked to add a locator that canonically resolves to
    /// the same physical directory as `existing`'s already-registered
    /// locator.
    case collision(
      existing: Institute.Materialization.ID,
      requested: Institute.Materialization.ID
    )

    /// `resolve`, `status`, or `forget` was asked about an id that is not
    /// registered.
    case notFound(Institute.Materialization.ID)

    /// `status` found `id` registered, but its locator no longer resolves
    /// to an existing directory on disk. Fail-closed: this is reported as
    /// a typed failure, never silently treated as valid.
    case missing(Institute.Materialization.ID)

    /// The registry ledger itself could not be read, decoded, or written.
    case workspace(Institute.Error)
  }
}

extension Institute.Materialization.Registry.Error: Swift.CustomStringConvertible {
  public var description: Swift.String {
    switch self {
    case .duplicate(let id):
      "materialization id \(id) is already registered"
    case .collision(let existing, let requested):
      "materialization \(requested) resolves to the same physical root as "
        + "already-registered \(existing)"
    case .notFound(let id):
      "no materialization is registered for id \(id)"
    case .missing(let id):
      "materialization \(id)'s registered root no longer exists on disk"
    case .workspace(let error):
      "\(error)"
    }
  }
}
