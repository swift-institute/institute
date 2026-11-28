package import SwiftSyntax

extension ManifestGraph {
    package struct Edge: Sendable {
        package var reference: Reference
        /// The traits the edge's condition names; empty when the edge has no trait condition.
        package let traits: [Swift::String]
        package let position: AbsolutePosition
    }
}

extension ManifestGraph.Edge {
    package var gated: Swift::Bool { !traits.isEmpty }
}
