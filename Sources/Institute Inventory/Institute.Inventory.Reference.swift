public import Institute_Model

extension Institute.Inventory {
    /// One place a type name chain is written.
    public struct Reference: Sendable, Hashable {
        /// The dotted path of the enclosing type or extension, empty at top level.
        public var from: [Swift.String]
        /// The module named by a `Module::` selector, or empty.
        public var module: Swift.String
        /// The chain as written, generic arguments dropped.
        public var chain: [Swift.String]
        public var position: Institute.Inventory.Position
        /// Whether the first component names a generic parameter or an
        /// associated type in scope.
        public var generic: Swift.Bool
    }
}

extension Institute.Inventory.Reference {
    /// `Module::A.B` or `A.B`.
    public var written: Swift.String {
        (module.isEmpty ? "" : module + "::") + chain.joined(separator: ".")
    }
}
