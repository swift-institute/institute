import Institute_CI_Model
import Institute_CI_GitHub
import Institute_CI_Workflow
import GitHub_Standard
import Institute_CI_Model

extension ContinuousIntegration.Inventory.Anchor.Staleness {
    /// What a source repository's `main` was observed to be.
    ///
    /// An input to the report, never something the report goes and
    /// fetches. The measurement is a network act with its own failure
    /// modes; folding it in here would make an advisory report able to
    /// fail, and a report that can fail is one someone will eventually
    /// gate on.
    public struct Observation: Sendable, Equatable {
        public let repository: String

        /// The observed tip of the source repository's `main`.
        public let head: ContinuousIntegration.Inventory.Anchor.Revision

        /// How many commits separate the pin from that tip, when the
        /// observer counted them. `nil` is *not measured* — never zero.
        public let distance: Int?

        public init(
            repository: String,
            head: ContinuousIntegration.Inventory.Anchor.Revision,
            distance: Int? = nil
        ) {
            self.repository = repository
            self.head = head
            self.distance = distance
        }
    }
}
