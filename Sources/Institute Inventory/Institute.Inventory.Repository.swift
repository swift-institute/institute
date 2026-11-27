internal import Institute_Model

extension Institute.Inventory {
    /// One repository under the root, as Git reports it.
    struct Repository: Sendable {
        var path: Swift.String
        var origin: Swift.String
        var head: Swift.String
        var dirty: Swift.Bool
    }
}
