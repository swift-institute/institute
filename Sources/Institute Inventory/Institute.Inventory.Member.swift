internal import Institute_Model
internal import Package_Manager

extension Institute.Inventory {
    /// One package whose manifest evaluated.
    struct Member: Sendable {
        var path: Swift.String
        var repository: Swift.String
        var evaluation: Package.Manifest.Evaluation
        var targets: [Target]
    }
}
