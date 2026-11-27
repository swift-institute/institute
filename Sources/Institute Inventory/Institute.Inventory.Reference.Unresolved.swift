internal import Institute_Model

extension Institute.Inventory.Reference {
    /// One row of `unresolved_references.json`: a chain that resolved to no type.
    struct Unresolved: Hashable, Comparable {
        var target: Swift.Int
        var written: Swift.String
    }
}

extension Institute.Inventory.Reference.Unresolved {
    static func < (lhs: Self, rhs: Self) -> Swift.Bool { (lhs.target, lhs.written) < (rhs.target, rhs.written) }
}
