public import Institute_CI_Model
public import Institute_Model

import struct Swift.String

extension Institute.CI.Validation.ThinCallers.Line.Reference {
    /// `<org>/.github/.github/workflows/<workflow>`: the coordinate a `uses:` line gives for a reusable workflow in an
    /// organization's `.github` repository. A repository and a file in it, not a file-system path.
    ///
    /// The double `.github` infix is what makes it one of these: from GitHub's point of view the calling repository is
    /// third-party, so the `<org>/.github` repository's own `.github/workflows/` directory is reached through the nested
    /// path. A third-party reusable has the single-infix shape and is not one.
    public struct Coordinate: Sendable, Equatable {
        /// The organization owning the `.github` repository.
        public let organization: String
        /// The workflow's file name inside that repository's `.github/workflows/`.
        public let workflow: String

        /// The coordinate `text` spells, or `nil` when it isn't one.
        public init?(_ text: String) {
            let segments = text.split(separator: "/", omittingEmptySubsequences: false)
            guard segments.count == 5, segments[1] == ".github", segments[2] == ".github",
                segments[3] == "workflows",
                segments[0].allSatisfy(Institute.CI.Validation.ThinCallers.Line.isReferenceCharacter),
                segments[4].allSatisfy(Institute.CI.Validation.ThinCallers.Line.isReferenceCharacter)
            else { return nil }
            self.organization = String(segments[0])
            self.workflow = String(segments[4])
        }

        /// The coordinate as a `uses:` line spells it.
        public var text: String { "\(organization)/.github/.github/workflows/\(workflow)" }
    }
}
