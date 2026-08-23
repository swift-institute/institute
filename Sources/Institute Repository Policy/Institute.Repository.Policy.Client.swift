public import Institute_Model

extension Institute.Repository.Policy {
    /// The typed seam between repository-policy semantics and whatever
    /// transport executes them. The domain owns the *contract* — the
    /// operations a wave may ask for and every way one refuses — while
    /// the application owns the executing client.
    public enum Client {}
}

extension Institute.Repository.Policy.Client {
    /// Every way one client operation refuses: an HTTP status outside
    /// the operation's contract, a transport failure underneath the
    /// request, a response body that does not decode, a response that
    /// violates the operation's preconditions, or a refusal raised by
    /// the Issue grammar during a compaction.
    public enum Error: Swift.Error, CustomStringConvertible, Sendable {
        case http(method: String, path: String, status: Int, response: String)
        case transport(path: String, message: String)
        case decoding(path: String, message: String)
        case precondition(String)
        case issue(RepositoryPolicy.Issue.Error)

        public var description: String {
            switch self {
            case .http(let method, let path, let status, let response):
                return "\(method) \(path) returned HTTP \(status): \(response)"

            case .transport(let path, let message):
                return "\(path): transport failure: \(message)"

            case .decoding(let path, let message):
                return "\(path): response did not decode: \(message)"

            case .precondition(let message):
                return message

            case .issue(let error):
                return "issue grammar refusal: \(error)"
            }
        }
    }
}
