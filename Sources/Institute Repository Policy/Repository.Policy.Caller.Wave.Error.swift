extension Repository.Policy.Caller.Wave {
    public enum Error: Swift.Error, CustomStringConvertible, Sendable {
        case attestation(String)
        case client(RepositoryPolicy.GitHubClient.Error)
        case invalidRepository(String)
        case population(String)
        case movedHead(repository: String, expected: String, actual: String)
        case movedBlob(repository: String, expected: String, actual: String)
        case ruleset(String)
        case journal(String)
        case verification(String)
        case restoration(primary: String, restore: String)

        public var description: String {
            switch self {
            case .attestation(let message): return message

            case .client(let error): return error.description

            case .invalidRepository(let message): return message

            case .population(let message): return message

            case .movedHead(let repository, let expected, let actual):
                return "\(repository): main moved from \(expected) to \(actual)"

            case .movedBlob(let repository, let expected, let actual):
                return "\(repository): caller moved from \(expected) to \(actual)"

            case .ruleset(let message): return message

            case .journal(let message): return message

            case .verification(let message): return message

            case .restoration(let primary, let restore):
                return "\(primary); ruleset restoration also failed: \(restore)"
            }
        }
    }
}
