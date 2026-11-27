public import Institute_Model

extension Institute.Inventory {
    /// What a written chain resolved to.
    public struct Resolution: Sendable, Hashable {
        /// One candidate per declaring target; empty when unresolved.
        public var candidates: [Candidate]
    }
}

extension Institute.Inventory.Resolution {
    public var ambiguous: Swift.Bool { Swift.Set(candidates.map(\.target)).count > 1 }
}
