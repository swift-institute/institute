public import Institute_Model

extension Institute.GitHub.Release {
    public enum Error: Swift.Error, Sendable, CustomStringConvertible {
        /// The `gh` transport itself failed.
        case transport(Institute.GitHub.Transport.Error)
        /// The API answered with a status the operation does not admit.
        case status(path: Swift.String, status: Swift.Int)
        /// The API answered with a shape the operation cannot read.
        case malformed(Swift.String)
        /// The release has no asset by the requested name.
        case missing(Swift.String)

        public var description: Swift.String {
            switch self {
            case .transport(let error): error.description
            case .status(let path, let status): "GET \(path) answered \(status)"
            case .malformed(let message): message
            case .missing(let message): message
            }
        }
    }
}
