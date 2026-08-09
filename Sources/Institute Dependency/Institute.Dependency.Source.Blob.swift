public import Institute_Model
internal import Institute_Inventory

extension Institute.Dependency.Source {
    /// One manifest blob named by a repository tree.
    public struct Blob: Equatable, Sendable {
        public let path: Swift.String
        public let object: Swift.String

        public init(path: Swift.String, object: Swift.String) {
            self.path = path
            self.object = object
        }
    }
}

extension Institute.Dependency.Source.Blob {
    /// Whether a blob path names a package manifest — `Package.swift` or a
    /// version-specific `Package@swift-<version>.swift`.
    ///
    /// The predicate is about manifests, not about the transport that
    /// enumerated the tree, so it belongs to Dependency rather than to the
    /// GitHub adapter it happened to be written beside.
    public static func isManifest(_ path: Swift.String) -> Swift.Bool {
        guard let name = path.split(separator: "/").last else { return false }
        return name == "Package.swift"
            || (
                name.hasPrefix("Package@swift-")
                    && name.hasSuffix(".swift")
                    && name.count > "Package@swift-.swift".count
            )
    }
}

