public import Institute_Model
public import Institute_CI_Model

extension Institute.CI.Canon {
    /// A complete generated repository `.gitignore` policy.
    ///
    /// The canonical text is a **whitelist**: `/*` denies every top-level
    /// entry and the `!/…` lines re-include the ones that carry real
    /// work, plus `**/.*/` denying tool-state dot-directories at every
    /// depth. That posture is why `.swift-lint/` — 3,384 files written
    /// into the worktree by swift-linter — was already ignored in every
    /// repository carrying the canonical file, without anyone having
    /// named it.
    ///
    /// The document is indivisible. Repository-local tails made the effective
    /// policy wider than the generated policy while still satisfying the old
    /// prefix comparison, so generation and validation now compare every byte.
    public struct Gitignore: Sendable, Equatable {
        /// The line that closes the canonical half. Matched as a
        /// substring, exactly as the retired pair matched it, so a file
        /// with trailing content on the marker line is still recognised.
        public static let terminator = "# ========== END CANONICAL =========="

        public let text: String

        public init(_ text: String) {
            self.text = text
        }

        /// Whether this is structurally a generated policy document.
        public var isGenerated: Bool {
            text.firstRange(of: Self.terminator) != nil
        }

        /// The bytes through the historical terminator. Kept only so a
        /// diagnostic can distinguish pre-generated input from a generated
        /// document with a forbidden tail.
        public var generatedPrefix: String? {
            guard let range = text.firstRange(of: Self.terminator) else { return nil }
            return String(text[text.startIndex..<range.upperBound]) + "\n"
        }
    }
}
