internal import Async_Fanout
public import Institute_Model
internal import Package_Manager

extension Institute.Workspace {
    /// A local-only workspace publication. It reads exact local manifests,
    /// plans generated state purely, and publishes only after every preflight passes.
    public struct Materialization: Sendable {
        public let root: Institute.Root
        public let specification: Institute.Workspace.Specification
        public let jobs: Swift.Int
        public let timeout: Swift.Duration

        public init(
            root: Institute.Root,
            specification: Institute.Workspace.Specification,
            jobs: Swift.Int = 32,
            timeout: Swift.Duration = .seconds(120)
        ) {
            self.root = root
            self.specification = specification
            self.jobs = jobs
            self.timeout = timeout
        }

        @discardableResult
        public func run() async throws(Institute.Error) -> Receipt {
            guard jobs > 0 else {
                throw .configuration("workspace materialization jobs must be greater than zero")
            }
            let catalog = try await Institute.Xcode.Acquisition.acquire(
                specification,
                at: root,
                packages: .init(),
                fanout: .init(jobs: jobs),
                timeout: timeout
            )
            let scheme = try Institute.Xcode.Scheme.plan(
                for: specification,
                catalog: catalog
            )
            let prepared = try Institute.Xcode.Publication.plan(
                specification: specification,
                catalog: catalog,
                scheme: scheme,
                at: root
            )
            try prepared.publication.apply()
            return prepared.receipt
        }
    }
}
