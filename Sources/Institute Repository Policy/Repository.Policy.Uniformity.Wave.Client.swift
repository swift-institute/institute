
extension Repository.Policy.Uniformity.Wave {
    /// The uniformity wave's effect surface. Refines the caller wave's
    /// client so every shared primitive — capacity, enumeration, heads,
    /// manifests, rulesets, blobs, ref moves, bounded pauses — is reused
    /// verbatim; only the shape observation and the multi-path forward
    /// commit are new.
    public protocol Client: Repository.Policy.Caller.Wave.Client {
        /// The exact file at `path` on `head`, or nil when absent.
        func shapeFile(
            _ repository: String,
            path: String,
            head: String
        ) async throws(RepositoryPolicy.GitHubClient.Error) -> File?
        /// One commit on `parent` that writes the root `.gitignore` to
        /// `gitignoreBlob` and deletes exactly `deletions`.
        func createShapeCommit(
            _ repository: String,
            parent: String,
            gitignoreBlob: String,
            deletions: [String],
            message: String
        ) async throws(RepositoryPolicy.GitHubClient.Error) -> String
    }
}
