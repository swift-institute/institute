public import Institute_Model

extension Institute.Inventory {
    /// A function, initializer, property, subscript or enum case that is
    /// not local to a body.
    public struct Symbol: Sendable, Hashable {
        /// The dotted path of the enclosing type or of the extended type; empty at top level.
        public var owner: [Swift.String]
        /// Whether an extension declares it directly.
        public var extended: Swift.Bool
        /// `func`, `init`, `var`, `let`, `subscript` or `case`.
        public var kind: Swift.String
        /// The name as a reference spells it: `parse(_:from:)`, `init(_:)`, `subscript(_:)`, `count`.
        public var name: Swift.String
        public var access: Swift.String
        /// Whether it is `static` or `class`.
        public var shared: Swift.Bool
        public var mutating: Swift.Bool
        public var async: Swift.Bool
        /// Empty, `throws`, `rethrows`, or the error type a typed `throws` names.
        public var thrown: Swift.String
        /// The names of its generic parameters.
        public var generics: [Swift.String]
        /// The type of each parameter as written, default values dropped.
        public var parameters: [Swift.String]
        /// The written return type, property type or subscript element type, or empty.
        public var result: Swift.String
        /// Whether it is a stored property.
        public var stored: Swift.Bool
        public var condition: Swift.String
        public var line: Swift.Int
    }
}
