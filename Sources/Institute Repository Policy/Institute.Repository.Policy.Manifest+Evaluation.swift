public import Institute_Model
public import Package_Manager

extension Institute.Repository.Policy.Manifest {
    /// Source-control dependency facts across every root manifest, in
    /// document order.
    public var dependencies: [Package.Manifest.Dependency.SourceControl] {
        documents.flatMap { document in
            Package.Manifest.Dependency.SourceControl.all(
                in: document.source,
                document: document.name
            )
        }
    }

    /// Package identities with distinct canonical locations across the
    /// root manifests and `Package.resolved`. Repositories exempt from the
    /// identity rule have none.
    public func identityFindings(
        repository: Swift.String
    ) -> [Package.Manifest.Identity.Conflict.Finding] {
        guard !Self.identityExempt(repository: repository) else { return [] }
        var entries: [Package.Manifest.Identity.Conflict.Entry] = []
        for document in documents {
            entries += Package.Manifest.Identity.Conflict.entries(
                in: document.source,
                document: document.name
            )
        }
        if let resolved {
            entries += Package.Manifest.Identity.Conflict.entries(inResolved: resolved)
        }
        return Package.Manifest.Identity.Conflict.findings(in: entries)
    }

    /// Whether `repository` (`owner/name`) is outside the identity rule.
    /// swift-html-prism is the one exemption.
    static func identityExempt(repository: Swift.String) -> Swift.Bool {
        repository.split(separator: "/").last == "swift-html-prism"
    }
}
