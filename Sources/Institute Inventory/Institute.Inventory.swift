public import Institute_Model

extension Institute {
    /// The inventory of every Swift package under a directory: its
    /// repositories, manifests, targets, imports, declared types and the
    /// places those types are named, written as flat JSON tables.
    ///
    /// It reads working trees as they are and changes nothing in them.
    public enum Inventory {}
}

extension Institute.Inventory {
    /// The places a type can be named, as `references.json` spells them.
    public enum Position: Swift.String, Sendable, Hashable, CaseIterable, Comparable {
        case stored
        case parameter
        case `return`
        case inheritance
        case `extension`
        case constraint
        case alias
        case genericArgument = "generic_argument"
        case `case`
        case body
        case other

        public static func < (lhs: Self, rhs: Self) -> Swift.Bool { lhs.rawValue < rhs.rawValue }
    }
}

extension Institute.Inventory {
    /// What one Swift source file declares, imports and names.
    public struct Facts: Sendable {
        public var lines: Swift.Int = 0
        public var imports: [Import] = []
        public var types: [Declaration] = []
        public var extensions: [Extension] = []
        public var references: [Reference] = []

        public init() {}
    }
}

extension Institute.Inventory.Facts {
    public struct Import: Sendable, Hashable {
        public var module: Swift.String
        public var access: Swift.String
        public var exported: Swift.Bool
        public var attributes: Swift.String
        public var condition: Swift.String
    }

    /// A nominal type or typealias.
    public struct Declaration: Sendable, Hashable {
        /// The dotted path, components without backticks.
        public var path: [Swift.String]
        public var moduleSelector: Swift.String
        public var kind: Swift.String
        public var access: Swift.String
        public var genericParameters: [Swift.String]
        /// A protocol's associated types; empty for any other kind.
        public var associatedTypes: [Swift.String] = []
        public var cases: Swift.Int
        public var storedProperties: Swift.Int
        public var inherits: [Swift.String]
        public var aliased: Swift.String
        public var inExtension: Swift.Bool
        public var condition: Swift.String
        public var line: Swift.Int

        public var name: Swift.String { path.last ?? "" }
    }

    public struct Extension: Sendable, Hashable {
        public var extended: [Swift.String]
        public var moduleSelector: Swift.String
        public var conformances: [Swift.String]
        public var whereClause: Swift.String
        public var publicMembers: Swift.Int
        public var nestedTypes: Swift.Int
        public var condition: Swift.String
        public var line: Swift.Int
    }

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

        /// `Module::A.B` or `A.B`.
        public var written: Swift.String {
            (module.isEmpty ? "" : module + "::") + chain.joined(separator: ".")
        }
    }
}
