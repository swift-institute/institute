public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Inventory.Anchor.Source {
    /// The content identity of a pinned source: which subtree is
    /// executed, and what its object name is.
    ///
    /// The second of the two independent facts a pin carries. The commit
    /// says *which revision was fetched*; the tree says *what the fetched
    /// bytes are*. They are independent because a commit can be
    /// re-pointed by a force-push and a tree cannot be anything other
    /// than its content — so an in-job check that both agree is a real
    /// check, where either alone is a single point of trust.
    ///
    /// `path` is the directory inside the source repository whose tree is
    /// recorded; `"."` names the repository root, which is the shape
    /// every source takes once it owns its own repository. A narrower
    /// path is retained because it is exactly what the pre-flip in-repo
    /// check recorded (`HEAD:Tools/institute-ci`), and a pin that cannot
    /// express the arrangement it replaces cannot be compared against it.
    public struct Tree: Sendable, Equatable {
        /// The repository-relative directory whose tree is recorded.
        public let path: String

        /// The recorded tree object name.
        public let oid: Institute.CI.Inventory.Anchor.Revision

        public init(
            path: String,
            oid: Institute.CI.Inventory.Anchor.Revision
        ) {
            self.path = path
            self.oid = oid
        }

        /// Whether this tree is the whole repository.
        public var isRoot: Bool { path == "." || path.isEmpty }

        /// The `git rev-parse` argument that names this tree from `HEAD`.
        public var revision: String { isRoot ? "HEAD^{tree}" : "HEAD:\(path)" }

        public var node: Institute.CI.Workflow.YAML.Node {
            .mapping(
                .init([
                    (.text("path"), .text(path)),
                    (.text("oid"), .text(oid.rawValue)),
                ])
            )
        }
    }
}
