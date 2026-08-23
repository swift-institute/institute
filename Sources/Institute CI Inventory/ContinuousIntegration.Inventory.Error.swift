import Institute_CI_Model
import Institute_CI_GitHub
import Institute_CI_Workflow
import GitHub_Standard
import Institute_CI_Model

extension ContinuousIntegration.Inventory {
    /// Why an inventory could not be derived.
    ///
    /// Every case names a construct the universal workflow is required
    /// to have. An inventory is a description of the shipped verdict; if
    /// the verdict's own scaffolding is missing, there is nothing to
    /// describe, and reporting an empty inventory would read as "the CI
    /// has no jobs" rather than "this file is not the universal".
    public enum Error: Swift.Error, Equatable {
        /// The workflow document could not be read as YAML.
        case unreadableWorkflow(message: String)
        /// The document has no `jobs:` mapping.
        case noJobs
        /// A job the aggregate depends on is absent.
        case missingJob(String)
        /// An object name is not a canonical 40-hex revision — an
        /// abbreviation, a ref, or an expression. Refused rather than
        /// resolved: resolution is what a pin exists to avoid.
        case malformedRevision(String)
        /// The trust anchor's own `uses:` reference is not identity
        /// pinned, which would leave the anchor anchored to a tag.
        case unpinnedAction(String)
        /// A trust anchor pins nothing. An empty anchor would report
        /// correspondence over zero sources — a gate that passes because
        /// it checked nothing.
        case noSources
        /// One source repository is pinned twice, so two pins claim
        /// authority over the same checkout.
        case duplicateSource(String)
        /// A recorded trust-anchor manifest could not be read as one.
        case unreadableAnchor(message: String)

        public var message: String {
            switch self {
            case .unreadableWorkflow(let message):
                "the universal workflow could not be read: \(message)"

            case .noJobs:
                "the universal workflow declares no jobs"

            case .missingJob(let job):
                "the universal workflow declares no '\(job)' job"

            case .malformedRevision(let text):
                "'\(text)' is not a canonical 40-hex object name, so it pins nothing"

            case .unpinnedAction(let reference):
                "the trust anchor's checkout action '\(reference)' is not pinned to a "
                    + "full commit SHA"

            case .noSources:
                "the trust anchor pins no source repositories"

            case .duplicateSource(let repository):
                "the trust anchor pins '\(repository)' more than once"

            case .unreadableAnchor(let message):
                "the trust-anchor manifest could not be read: \(message)"
            }
        }
    }
}
