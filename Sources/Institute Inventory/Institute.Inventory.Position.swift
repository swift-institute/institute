public import Institute_Model

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
    }
}

extension Institute.Inventory.Position {
    /// The position as the tables spell it.
    public var spelling: Swift.String { self.rawValue }

    public static func < (lhs: Self, rhs: Self) -> Swift.Bool { lhs.rawValue < rhs.rawValue }
}
