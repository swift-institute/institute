import Institute_CI_Model
import Institute_CI_GitHub
import Institute_CI_Workflow
import GitHub_Standard
import Institute_CI_Model

extension ContinuousIntegration.Inventory {
    /// One `actions/cache` step, and what it caches.
    ///
    /// Enumerated because the cache policy carries one standing
    /// prohibition — `.build/` is never cached, so a green run is never
    /// green because of a stale object file. The inventory records the
    /// paths; the assertion over them lives in the test suite, where a
    /// violation reads as a failure rather than as a field.
    public struct CacheStep: Sendable, Equatable {
        public let job: String
        public let step: String?
        public let path: GitHub.ContinuousIntegration.Workflow.YAML.Node?
        public let key: GitHub.ContinuousIntegration.Workflow.YAML.Node?

        public init(
            job: String,
            step: String?,
            path: GitHub.ContinuousIntegration.Workflow.YAML.Node?,
            key: GitHub.ContinuousIntegration.Workflow.YAML.Node?
        ) {
            self.job = job
            self.step = step
            self.path = path
            self.key = key
        }

        public var node: GitHub.ContinuousIntegration.Workflow.YAML.Node {
            .mapping(
                .init([
                    (.text("job"), .text(job)),
                    (
                        .text("step"),
                        step.map(GitHub.ContinuousIntegration.Workflow.YAML.Node.text) ?? .null
                    ),
                    (.text("path"), path ?? .null),
                    (.text("key"), key ?? .null),
                ])
            )
        }
    }
}
