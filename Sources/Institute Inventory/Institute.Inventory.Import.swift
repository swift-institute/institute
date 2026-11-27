public import Institute_Model

extension Institute.Inventory {
    /// One `import` declaration.
    public struct Import: Sendable, Hashable {
        public var module: Swift.String
        public var access: Swift.String
        public var exported: Swift.Bool
        public var attributes: Swift.String
        public var condition: Swift.String
    }
}
