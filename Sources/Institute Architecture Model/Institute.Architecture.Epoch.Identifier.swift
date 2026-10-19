public import Institute_Model

extension Institute.Architecture.Epoch {
    /// The epoch's identity within its owner's migration history.
    public struct Identifier: Sendable, Equatable, Hashable, RawRepresentable {
        public let rawValue: Swift.String

        public init(rawValue: Swift.String) {
            self.rawValue = rawValue
        }
    }
}

extension Institute.Architecture.Epoch.Identifier: Comparable {
    public static func < (
        lhs: Institute.Architecture.Epoch.Identifier,
        rhs: Institute.Architecture.Epoch.Identifier
    ) -> Swift.Bool {
        lhs.rawValue < rhs.rawValue
    }
}
