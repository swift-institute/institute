package import SwiftSyntax

extension ManifestGraph {
    package struct Target: Sendable {
        package let name: Swift::String
        package let kind: Kind
        package let path: Swift::String?
        package let position: AbsolutePosition
        package var edges: [Edge]
    }
}

extension ManifestGraph.Target {
    /// The folder of the target's sources, relative to the package root.
    package var directory: Swift::String {
        path ?? ((kind == .test ? "Tests/" : "Sources/") + name)
    }
}
