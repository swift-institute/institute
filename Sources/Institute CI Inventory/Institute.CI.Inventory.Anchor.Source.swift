public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Inventory.Anchor {
    /// One pinned source repository: where it is fetched from, at which
    /// revision, into which workspace path, and what its content is.
    ///
    /// A source is a *fetch coordinate plus two identities*. The
    /// coordinate is what a content hash alone cannot supply — a digest
    /// says whether the right bytes arrived, never where to get them —
    /// and the two identities are what a coordinate alone cannot supply.
    /// All four fields are generated together; none is separately
    /// editable, because a commit edited without its tree describes a
    /// revision that was never measured.
    public struct Source: Sendable, Equatable {
        /// `owner/name`, as `actions/checkout` spells it.
        public let repository: String

        /// The workspace-relative directory the checkout lands in.
        public let checkout: String

        /// The pinned commit — a literal object name, never a ref.
        public let commit: Revision

        /// The executed subtree and its object name.
        public let tree: Tree

        public init(repository: String, checkout: String, commit: Revision, tree: Tree) {
            self.repository = repository
            self.checkout = checkout
            self.commit = commit
            self.tree = tree
        }

        /// The repository's own name, without its owner.
        public var name: String {
            repository.split(separator: "/").last.map(String.init) ?? repository
        }

        /// The step id the identity check reports under: the repository
        /// name reduced to what Actions accepts in an id, which is
        /// derived rather than authored so two sources cannot be given
        /// the same one by hand.
        public var identifier: String {
            var slug = ""
            var pending = false
            for character in name.lowercased() {
                let isKept = ("a"..."z").contains(character) || ("0"..."9").contains(character)
                if isKept {
                    if pending, !slug.isEmpty { slug.append("-") }
                    pending = false
                    slug.append(character)
                } else {
                    pending = true
                }
            }
            return slug
        }

        public var node: Institute.CI.Workflow.YAML.Node {
            .mapping(
                .init([
                    (.text("repository"), .text(repository)),
                    (.text("checkout"), .text(checkout)),
                    (.text("commit"), .text(commit.rawValue)),
                    (.text("tree"), tree.node),
                ])
            )
        }
    }
}
