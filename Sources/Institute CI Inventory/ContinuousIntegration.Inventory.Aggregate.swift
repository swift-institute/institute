import Institute_CI_Model
import Institute_CI_GitHub
import Institute_CI_Workflow
import GitHub_Standard
import Institute_CI_Model

/// The vendor-neutral contract type, aliased at file scope so the
/// reference cannot rebind to the `ContinuousIntegration`
/// nest inside the extension below.
private typealias ContractRequirement = ContinuousIntegration.Requirement

extension ContinuousIntegration.Inventory {
    /// The single aggregate: `ci-ok`, its advisory counterpart, and the
    /// one required check context they resolve to.
    ///
    /// There is exactly one verdict-bearing aggregate in the shipped
    /// topology. The retired inventory carried an outer/inner pair — a
    /// layer wrapper's own `ci-ok` trusting the universal's as an opaque
    /// signal — which described a hop that no longer exists.
    ///
    /// One inner aggregate does survive, and it is GitHub-native rather
    /// than authored: a job carrying a `strategy.matrix` reports one
    /// check per leg and one aggregate check for the job. Those are
    /// enumerated in `innerMatrixJobs` precisely so that a reader can
    /// see they feed nothing gating.
    public struct Aggregate: Sendable, Equatable {
        public static let step = "Aggregate required-job results"

        /// The required check context, from its owner. It never migrates.
        public static var checkContext: String { ContractRequirement.checkContext }

        public let ciOkNeeds: [String]
        public let advisorySummaryNeeds: [String]
        public let innerMatrixJobs: [String]

        public init(
            ciOkNeeds: [String],
            advisorySummaryNeeds: [String],
            innerMatrixJobs: [String]
        ) {
            self.ciOkNeeds = ciOkNeeds
            self.advisorySummaryNeeds = advisorySummaryNeeds
            self.innerMatrixJobs = innerMatrixJobs
        }

        /// `ci-ok`'s needs minus `plan` — the gating partition.
        public var gatingJobs: [String] { ciOkNeeds.filter { $0 != "plan" } }

        /// `advisory-summary`'s needs minus `plan`.
        public var advisoryJobs: [String] { advisorySummaryNeeds.filter { $0 != "plan" } }

        public var node: GitHub.ContinuousIntegration.Workflow.YAML.Node {
            .mapping(
                .init([
                    (
                        .text("ci_ok_needs"),
                        .sequence(
                            ciOkNeeds.map(GitHub.ContinuousIntegration.Workflow.YAML.Node.text)
                        )
                    ),
                    (.text("ci_ok_step"), .text(Self.step)),
                    (
                        .text("advisory_summary_needs"),
                        .sequence(
                            advisorySummaryNeeds.map(
                                GitHub.ContinuousIntegration.Workflow.YAML.Node.text
                            )
                        )
                    ),
                    (
                        .text("inner_matrix_jobs"),
                        .sequence(
                            innerMatrixJobs.map(
                                GitHub.ContinuousIntegration.Workflow.YAML.Node.text
                            )
                        )
                    ),
                    (.text("required_check_context"), .text(Self.checkContext)),
                ])
            )
        }
    }
}
