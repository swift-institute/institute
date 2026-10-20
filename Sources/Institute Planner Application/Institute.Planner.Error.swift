public import Institute_Model

extension Institute.Planner {
    /// Every way the planner contract or one of its verbs refuses. Each
    /// case names the condition, never the recovery.
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        /// A pin, planner, PIN or SHA256SUMS line does not have its shape.
        case malformed(line: Swift.String, reason: Swift.String)
        /// A row names a platform the planner is not published for.
        case platform(Swift.String)
        /// A required release asset or consumer file does not exist.
        case missing(Swift.String)
        /// More than one asset answers where the contract admits one.
        case ambiguous(Swift.String)
        /// An asset's bytes do not hash to the digest its row or checksum names.
        case mismatch(asset: Swift.String, expected: Swift.String, actual: Swift.String)
        /// The pinned revision has no row for a platform.
        case absent(revision: Swift.String, platform: Swift.String)
        /// A winning row is not carried verbatim by any published PIN asset.
        case unpublished(Swift.String)
        /// Canary evidence does not admit adoption.
        case evidence(Swift.String)
        /// The GitHub transport failed.
        case transport(Swift.String)
        /// A local file, directory, or process effect failed.
        case local(Swift.String)

        public var description: Swift.String {
            switch self {
            case .malformed(let line, let reason): "malformed line '\(line)': \(reason)"
            case .platform(let platform): "unknown platform '\(platform)'"
            case .missing(let subject): "missing \(subject)"
            case .ambiguous(let subject): "ambiguous \(subject)"
            case .mismatch(let asset, let expected, let actual):
                "\(asset) hashes to \(actual), not \(expected)"
            case .absent(let revision, let platform):
                "pinned revision \(revision) has no planner row for \(platform)"
            case .unpublished(let row):
                "planner row was not published by any PIN asset: '\(row)'"
            case .evidence(let message): message
            case .transport(let message): message
            case .local(let message): message
            }
        }
    }
}
