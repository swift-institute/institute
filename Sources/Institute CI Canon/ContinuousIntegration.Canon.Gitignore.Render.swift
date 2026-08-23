import ASCII
import Institute_CI_Model

extension ContinuousIntegration.Canon.Gitignore {
    /// The propagation half of the gitignore pair — the Swift owner of
    /// `.github/scripts/render-gitignore.py`, driven by
    /// `sync-gitignore.yml`.
    ///
    /// Rendering is deterministic and byte-compared by the caller. The canon
    /// is the complete policy: existing handwritten content is never spliced
    /// onto it.
    public struct Render: Sendable, Equatable {
        /// The whole generated policy.
        public let canon: String

        public init(canon: ContinuousIntegration.Canon.Gitignore) throws(Error) {
            guard canon.isGenerated else { throw .terminatorAbsent }
            // Git may materialize a text checkout with CRLF on Windows.
            // The canon is one Git document whose blob remains LF-pinned;
            // line-ending conversion must not make its closed admission
            // vocabulary disappear from the parser.
            let normalized = canon.text.normalized(to: .lf)
            guard
                normalized.contains(
                    ContinuousIntegration.Canon.Gitignore.Capability.block
                )
            else { throw .capabilityBlockAbsent }
            self.canon = canon.text
        }
    }
}

extension ContinuousIntegration.Canon.Gitignore.Render {
    /// The file to write into a repository. Existing bytes do not affect the
    /// result because no post-generation policy fragment is lawful.
    public func callAsFunction(
        over existing: ContinuousIntegration.Canon.Gitignore?
    ) -> String {
        _ = existing
        return canon
    }

    /// The one way a canonical document refuses.
    ///
    /// Refusing is about *canon*, never about the package under it: an
    /// unusable control-plane document is not a verdict on any
    /// repository, and the two must not travel on the same channel.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Canon carries no `END CANONICAL` terminator.
        case terminatorAbsent
        case capabilityBlockAbsent

        public var message: String {
            switch self {
            case .terminatorAbsent:
                "canon has no \(ContinuousIntegration.Canon.Gitignore.terminator) marker"

            case .capabilityBlockAbsent:
                "canon has no closed six-capability admission block"
            }
        }
    }
}
