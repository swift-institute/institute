public import Institute_Model

extension Institute.Architecture.Edge {
    /// The dependency closure records six edge kinds; a graph question is
    /// only meaningful once the kind is named.
    public enum Kind: Sendable, Equatable, Hashable, CaseIterable {
        /// A manifest product dependency reachable at runtime.
        case runtime
        /// A target-level dependency inside one package.
        case target
        /// An edge present only through SwiftPM resolution.
        case resolution
        /// A host-tool edge (plugins, build tools).
        case host
        /// An edge reachable only from test targets.
        case test
        /// The record of where a fact was derived from.
        case provenance
    }
}

extension Institute.Architecture.Edge.Kind {
    public var name: Swift.String {
        switch self {
        case .runtime: "runtime"
        case .target: "target"
        case .resolution: "resolution"
        case .host: "host"
        case .test: "test"
        case .provenance: "provenance"
        }
    }
}

extension Institute.Architecture.Edge.Kind: Comparable {
    public static func < (
        lhs: Institute.Architecture.Edge.Kind,
        rhs: Institute.Architecture.Edge.Kind
    ) -> Swift.Bool {
        lhs.name < rhs.name
    }
}
