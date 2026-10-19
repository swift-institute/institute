public import Institute_Model

extension Institute.Architecture {
    /// One of the four Institute layers, as `swift-institute/.github`'s
    /// `.github/policy/fleet.json` assigns them to organizations: L1
    /// `swift-atoms`, L2 `swift-molecules`, L3 `swift-standards` (with the
    /// specification authorities and vendors), L4 `swift-compositions`.
    ///
    /// Dependency edges point from higher layers to lower layers; the
    /// ``rank`` orders the layers so an edge's legality is a single
    /// comparison.
    public enum Layer: Sendable, Equatable, Hashable, CaseIterable {
        case atoms
        case molecules
        case standards
        case compositions
    }
}

extension Institute.Architecture.Layer {
    /// The layer's height: a target may depend only on layers whose rank is
    /// less than or equal to its own.
    public var rank: Swift.Int {
        switch self {
        case .atoms: 1
        case .molecules: 2
        case .standards: 3
        case .compositions: 4
        }
    }

    /// The inventory spelling, exactly as `Institute.json` records it.
    public var name: Swift.String {
        switch self {
        case .atoms: "atoms"
        case .molecules: "molecules"
        case .standards: "standards"
        case .compositions: "compositions"
        }
    }

    public init?(name: Swift.String) {
        switch name {
        case "atoms": self = .atoms
        case "molecules": self = .molecules
        case "standards": self = .standards
        case "compositions": self = .compositions
        default: return nil
        }
    }
}

extension Institute.Architecture.Layer: Comparable {
    public static func < (
        lhs: Institute.Architecture.Layer,
        rhs: Institute.Architecture.Layer
    ) -> Swift.Bool {
        lhs.rank < rhs.rank
    }
}
