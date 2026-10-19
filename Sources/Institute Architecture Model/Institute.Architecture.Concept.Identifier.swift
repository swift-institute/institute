public import Institute_Model

extension Institute.Architecture.Concept {
    /// The concept's identity.
    ///
    /// Derived deterministically from the owning coordinate
    /// (`organization/name`); it is the only ground on which two facts may
    /// be judged to describe the same concept.
    public struct Identifier: Sendable, Equatable, Hashable, RawRepresentable {
        public let rawValue: Swift.String

        public init(rawValue: Swift.String) {
            self.rawValue = rawValue
        }

        public init(owner: Institute.Architecture.Owner) {
            self.rawValue = "\(owner.organization)/\(owner.name)"
        }
    }
}

extension Institute.Architecture.Concept.Identifier: CustomStringConvertible {
    public var description: Swift.String {
        rawValue
    }
}

extension Institute.Architecture.Concept.Identifier: Comparable {
    public static func < (
        lhs: Institute.Architecture.Concept.Identifier,
        rhs: Institute.Architecture.Concept.Identifier
    ) -> Swift.Bool {
        lhs.rawValue < rhs.rawValue
    }
}
