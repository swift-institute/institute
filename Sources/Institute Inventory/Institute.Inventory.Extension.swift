public import Institute_Model

extension Institute.Inventory {
    /// One `extension` declaration.
    public struct Extension: Sendable, Hashable {
        public var extended: [Swift.String]
        /// The module named by a `Module::` selector on the extended type, or empty.
        public var module: Swift.String
        public var conformances: [Swift.String]
        /// The requirements of its `where` clause as written, or empty.
        public var requirements: Swift.String
        /// How many of its members are public, by their own modifier or the extension's.
        public var surface: Swift.Int
        /// How many types and typealiases it declares.
        public var nested: Swift.Int
        public var condition: Swift.String
        public var line: Swift.Int
    }
}
