internal import Institute_Model
internal import Package_Manager

extension Institute.Inventory {
    /// One target of a package, with the Swift files under its directory.
    struct Target: Sendable {
        var package: Swift.Int
        var manifest: Package.Manifest.Target
        var name: Swift.String
        /// The source directory relative to the package, empty when none exists.
        var path: Swift.String
        var files: [Swift.String]
    }
}
