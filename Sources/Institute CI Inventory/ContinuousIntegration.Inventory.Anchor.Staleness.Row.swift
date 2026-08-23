import Institute_CI_Model
import Institute_CI_GitHub
import Institute_CI_Workflow
import GitHub_Standard
import Institute_CI_Model

extension ContinuousIntegration.Inventory.Anchor.Staleness {
    /// One source's line of the staleness report.
    ///
    /// Three states, and the third is the one that matters: a source with
    /// no observation is `unmeasured`, which is neither current nor
    /// behind. A report that rendered an unobserved source as up to date
    /// would be worse than no report, since the whole value of this one
    /// is telling a reader which pins they have actually looked at.
    public struct Row: Sendable, Equatable {
        public let repository: String

        /// The pinned commit.
        public let pinned: ContinuousIntegration.Inventory.Anchor.Revision

        /// The observed tip of `main`, when observed.
        public let head: ContinuousIntegration.Inventory.Anchor.Revision?

        /// Commits between the pin and the tip, when counted.
        public let distance: Int?

        public init(
            repository: String,
            pinned: ContinuousIntegration.Inventory.Anchor.Revision,
            head: ContinuousIntegration.Inventory.Anchor.Revision?,
            distance: Int?
        ) {
            self.repository = repository
            self.pinned = pinned
            self.head = head
            self.distance = distance
        }

        /// Whether this source's `main` was observed at all.
        public var isMeasured: Bool { head != nil }

        /// Whether the pin is the observed tip. False when unmeasured —
        /// not-knowing is never agreement.
        public var isCurrent: Bool { head == pinned }

        public var node: GitHub.ContinuousIntegration.Workflow.YAML.Node {
            .mapping(
                .init([
                    (.text("repository"), .text(repository)),
                    (.text("pinned"), .text(pinned.rawValue)),
                    (
                        .text("head"),
                        head.map {
                            GitHub.ContinuousIntegration.Workflow.YAML.Node.text($0.rawValue)
                        } ?? .null
                    ),
                    (
                        .text("distance"),
                        distance.map(GitHub.ContinuousIntegration.Workflow.YAML.Node.integer)
                            ?? .null
                    ),
                    (.text("measured"), .boolean(isMeasured)),
                    (.text("current"), .boolean(isCurrent)),
                ])
            )
        }
    }
}
