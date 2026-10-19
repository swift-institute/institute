public import Institute_Model

extension Institute.Architecture {
    /// One typed dependency edge between two package roots.
    ///
    /// The direction reads "``source`` depends on ``destination``".
    public struct Edge: Sendable, Equatable, Hashable {
        public let source: Owner
        public let destination: Owner
        public let kind: Kind

        public init(source: Owner, destination: Owner, kind: Kind) {
            self.source = source
            self.destination = destination
            self.kind = kind
        }
    }
}

extension Institute.Architecture.Edge: Comparable {
    public static func < (
        lhs: Institute.Architecture.Edge,
        rhs: Institute.Architecture.Edge
    ) -> Swift.Bool {
        if lhs.source != rhs.source { return lhs.source < rhs.source }
        if lhs.destination != rhs.destination { return lhs.destination < rhs.destination }
        return lhs.kind < rhs.kind
    }
}

extension Institute.Architecture.Edge: CustomStringConvertible {
    public var description: Swift.String {
        "\(source) -[\(kind.name)]-> \(destination)"
    }
}
