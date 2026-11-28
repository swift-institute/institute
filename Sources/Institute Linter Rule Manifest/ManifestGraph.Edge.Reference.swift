extension ManifestGraph.Edge {
    package enum Reference: Sendable, Hashable {
        case target(Swift::String)
        case product(Swift::String, package: Swift::String)
    }
}
