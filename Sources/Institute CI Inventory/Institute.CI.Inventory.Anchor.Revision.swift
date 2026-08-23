public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Inventory.Anchor {
    /// One git object name, in its canonical 40-hex spelling.
    ///
    /// A typed value rather than a `String` because the whole point of
    /// the trust anchor is that a pin is a *literal* object name. An
    /// abbreviated SHA, a branch, a tag, or an Actions expression are all
    /// perfectly good `String`s and none of them pin anything: the first
    /// two resolve differently over time, the third has no authority
    /// behind it (the Institute mints no tags), and the fourth resolves
    /// inside a run rather than in the file. Refusing them at
    /// construction means no later stage has to re-ask.
    ///
    /// Upper case is refused rather than normalised. Git emits lower
    /// case; a pin spelled otherwise did not come from `git rev-parse`,
    /// and quietly folding it would erase the only evidence of that.
    public struct Revision: Sendable, Equatable, Hashable, CustomStringConvertible {
        /// The canonical width of a full object name.
        public static let width = 40

        public let rawValue: String

        /// The revision, or a refusal.
        public init(
            _ text: String
        ) throws(Institute.CI.Inventory.Error) {
            guard Self.isCanonical(text) else { throw .malformedRevision(text) }
            self.rawValue = text
        }

        public var description: String { rawValue }

        /// Exactly `width` lower-case hex digits, and nothing else.
        public static func isCanonical(_ text: String) -> Bool {
            guard text.count == width else { return false }
            return text.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
        }
    }
}
