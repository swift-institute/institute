package struct PackageTargetImportEdgeManifest {
    package var targets: [PackageTargetImportEdgeTarget] = []

    package var products: [Swift::String: Swift::Set<Swift::String>] = [:]

    package var urlDependencies: [Swift::String] = []

    package var pathDependencies: [Swift::String] = []
}
