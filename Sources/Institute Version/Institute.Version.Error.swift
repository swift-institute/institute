public import Institute_Model

extension Institute.Version {
    /// Every way a read or write of the tagging client fails. Each case
    /// names the condition, never the recovery.
    public enum Error: Swift.Error, Swift.Sendable, Swift.Hashable, Swift.CustomStringConvertible {
        /// The GitHub transport itself failed.
        case transport(Swift.String)
        /// The API answered with a status the operation does not admit.
        case status(method: Swift.String, path: Swift.String, status: Swift.Int)
        /// The API answered with a shape the operation cannot read.
        case malformed(Swift.String)

        public var description: Swift.String {
            switch self {
            case .transport(let message): message
            case .status(let method, let path, let status): "\(method) \(path) answered \(status)"
            case .malformed(let message): message
            }
        }
    }
}
