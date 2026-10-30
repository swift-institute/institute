public import Institute_Model
import Package_Manager

extension Institute.Repository.Policy.Manifest {
    /// Reads the root manifests at `root`. An unreadable root is a refusal;
    /// a manifest that is listed but unreadable contributes nothing, as
    /// does a missing `Package.resolved`.
    public static func read(at root: Swift.String) throws(Error) -> Self {
        guard let names = Institute.Repository.Policy.names(at: root) else {
            throw .unreadableRoot(root)
        }
        let documents = names.filter(Package.Manifest.Identity.Conflict.isRootManifest)
            .compactMap { name -> Document? in
                Institute.Repository.Policy.text(at: root + "/" + name)
                    .map { Document(name: name, source: $0) }
            }
        return Self(
            documents: documents,
            resolved: Institute.Repository.Policy.text(at: root + "/Package.resolved")
        )
    }
}
