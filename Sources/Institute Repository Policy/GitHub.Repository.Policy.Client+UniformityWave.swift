
extension RepositoryPolicy.GitHubClient: Institute_Repository_Policy.Repository.Policy.Uniformity.Wave.Client
{
    public func shapeFile(
        _ repository: String,
        path: String,
        head: String
    ) async throws(Error) -> Institute_Repository_Policy.Repository.Policy.Uniformity.Wave.File? {
        try await uniformityWaveFileIfPresent(repository, path: path, head: head)
    }

    public func createShapeCommit(
        _ repository: String,
        parent: String,
        gitignoreBlob: String,
        deletions: [String],
        message: String
    ) async throws(Error) -> String {
        try await uniformityWaveCreateCommit(
            repository,
            parent: parent,
            gitignoreBlob: gitignoreBlob,
            deletions: deletions,
            message: message
        )
    }
}
