internal import Institute_Model

extension Institute.Inventory.Reference {
    /// One row of `references.json`: a reference as one target writes it.
    struct Key: Hashable, Comparable {
        var target: Swift.Int
        var from: [Swift.String]
        var module: Swift.String
        var chain: [Swift.String]
        var position: Institute.Inventory.Position
        var generic: Swift.Bool
    }
}

extension Institute.Inventory.Reference.Key {
    var written: Swift.String { (module.isEmpty ? "" : module + "::") + chain.joined(separator: ".") }

    static func < (lhs: Self, rhs: Self) -> Swift.Bool {
        (lhs.target, lhs.from.joined(separator: "."), lhs.written, lhs.position, lhs.generic ? 1 : 0)
            < (rhs.target, rhs.from.joined(separator: "."), rhs.written, rhs.position, rhs.generic ? 1 : 0)
    }
}
