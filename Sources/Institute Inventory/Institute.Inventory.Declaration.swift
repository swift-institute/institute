public import Institute_Model

extension Institute.Inventory {
    /// A nominal type or typealias.
    public struct Declaration: Sendable, Hashable {
        /// The dotted path, components without backticks.
        // swift-linter:disable:next raw concept
        // REASON: a declared type's dotted path, such as Picture.Encoded.Pixel, one component per name; it names no file.
        public var path: [Swift.String]
        /// The module named by a `Module::` selector on the enclosing extension, or empty.
        public var module: Swift.String
        public var kind: Swift.String
        public var access: Swift.String
        /// The names of its generic parameters.
        public var generics: [Swift.String]
        /// A protocol's associated types; empty for any other kind.
        public var associated: [Swift.String] = []
        public var cases: Swift.Int
        /// How many stored instance properties it declares.
        public var stored: Swift.Int
        public var inherits: [Swift.String]
        public var aliased: Swift.String
        public var isInExtension: Swift.Bool
        public var condition: Swift.String
        public var line: Swift.Int
    }
}

extension Institute.Inventory.Declaration {
    public var name: Swift.String { path.last ?? "" }
}
