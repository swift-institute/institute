internal import Institute_Model

extension Institute.Inventory.Reference {
    /// One row of `resolved_references.json`: a reference and one type it resolves to.
    struct Resolved: Hashable, Comparable {
        var target: Swift.Int
        var from: Swift.String
        var position: Institute.Inventory.Position
        var path: Swift.String
        var declaring: Swift.Int
        var ambiguous: Swift.Bool
    }
}

extension Institute.Inventory.Reference.Resolved {
    static func < (lhs: Self, rhs: Self) -> Swift.Bool {
        (lhs.target, lhs.from, lhs.position, lhs.path, lhs.declaring)
            < (rhs.target, rhs.from, rhs.position, rhs.path, rhs.declaring)
    }
}
