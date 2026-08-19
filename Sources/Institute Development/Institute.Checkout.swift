public import File_System
public import Git_Foundation
public import Institute_Model

extension Institute {
    /// An isolated, certifier-owned detached checkout of one exact revision.
    ///
    /// This is the exact-source counterpart to ``Institute/Sync``: sync
    /// materializes the *moving* development state — a long-lived `main`
    /// checkout that fast-forwards — while a checkout materializes one
    /// *frozen* commit into a destination nothing else owns, for evaluation
    /// that must observe exactly the bytes that commit names.
    ///
    /// The commit is obtained from Git's content-addressed object store,
    /// never from anyone's working tree: a local repository may serve as the
    /// object source, but modified, staged, deleted, or untracked files in
    /// its worktree are not objects the named commit references and cannot
    /// reach the materialized tree. When the local store lacks the commit,
    /// it is fetched from the canonical remote *by exact object name* — a
    /// branch tip is never resolved, so remote movement after the revision
    /// was selected cannot change what materializes.
    public struct Checkout: Sendable {
        public let client: Git.Client

        public init(client: Git.Client = .init()) {
            self.client = client
        }
    }
}

extension Institute.Checkout {
    /// Materializes exactly `revision` into `destination`.
    ///
    /// The destination must not exist: the materialized tree is created
    /// complete at a staging sibling and published by one atomic move, so
    /// an interrupted materialization leaves either nothing at the
    /// destination or the complete verified tree — never a partial state,
    /// and never a mutation of any existing directory.
    ///
    /// - Parameters:
    ///   - url: the repository's canonical remote, used only for an exact
    ///     object fetch when the object source lacks the commit.
    ///   - objects: an optional local repository whose *object store* seeds
    ///     the clone. Its working tree contributes nothing.
    ///   - revision: the exact commit to materialize.
    ///   - destination: where the verified tree is published.
    public func materialize(
        url: Swift.String,
        objects: Swift.String? = nil,
        revision: Git.Object.ID,
        to destination: File.Directory
    ) throws(Institute.Error) -> Materialized {
        guard !File.System.Stat.exists(at: destination.path) else {
            throw .filesystem(
                "checkout destination already exists: \(destination) — a materialization "
                    + "publishes into a path nothing else owns, never over one"
            )
        }
        if let parent = destination.path.parent {
            do throws(File.System.Create.Directory.Error) {
                try File.Directory(parent).create.recursive()
            } catch {
                throw .filesystem("cannot create checkout destination parent \(parent): \(error)")
            }
        }

        let temporaryPath: File.Path
        do throws(File.Path.Temporary.Error) {
            temporaryPath = try File.Path.Temporary.sibling(
                of: destination.path,
                prefix: ".checkout-",
                suffix: ".staging"
            )
        } catch {
            throw .filesystem("cannot create a checkout staging path: \(error)")
        }
        let staging = File.Directory(temporaryPath)

        do throws(Institute.Error) {
            try populate(
                staging,
                url: url,
                objects: objects,
                revision: revision
            )
        } catch {
            // Cleanup discard is deliberate — the populate error below is
            // the one worth reporting, not a failure to remove staging.
            do throws(File.System.Delete.Error) {
                try staging.delete.recursive()
            } catch {}
            throw error
        }

        let tree: Git.Object.ID
        do throws(Institute.Error) {
            tree = try verify(staging, revision: revision)
        } catch {
            do throws(File.System.Delete.Error) {
                try staging.delete.recursive()
            } catch {}
            throw error
        }

        do throws(File.System.Move.Error) {
            try staging.move.to(destination)
        } catch {
            do throws(File.System.Delete.Error) {
                try staging.delete.recursive()
            } catch {}
            throw .filesystem("cannot publish checkout to \(destination): \(error)")
        }

        return .init(revision: revision, tree: tree, directory: destination)
    }

    private func populate(
        _ staging: File.Directory,
        url: Swift.String,
        objects: Swift.String?,
        revision: Git.Object.ID
    ) throws(Institute.Error) {
        // Clone without checkout: this transports objects and writes no
        // worktree, so no branch tip has selected any bytes yet.
        try execute { () throws(Git.Client.Error) in
            try client.clone(objects ?? url, checkout: false, to: staging.description)
        }

        let contains = try execute { () throws(Git.Client.Error) in
            try client.contains(commit: revision, at: staging.description)
        }
        if !contains {
            // Exact object fetch from the canonical remote. The refspec
            // names the commit itself; a branch tip is never consulted.
            let anchor = try reference("refs/checkout/exact")
            do throws(Institute.Error) {
                try execute { () throws(Git.Client.Error) in
                    try client.fetch(url, object: revision, into: anchor, at: staging.description)
                }
            } catch {
                throw .repository(
                    "revision \(revision.rawValue) is not in the object source and the "
                        + "canonical remote \(url) cannot supply it exactly: \(error)"
                )
            }
        }

        try execute { () throws(Git.Client.Error) in
            try client.checkout(detached: revision, at: staging.description)
        }
    }

    private func verify(
        _ staging: File.Directory,
        revision: Git.Object.ID
    ) throws(Institute.Error) -> Git.Object.ID {
        let head = try execute { () throws(Git.Client.Error) in
            try client.head(at: staging.description)
        }
        guard head == revision else {
            throw .repository(
                "materialized HEAD \(head.rawValue) is not the requested "
                    + "revision \(revision.rawValue)"
            )
        }

        let entries = try execute { () throws(Git.Client.Error) in
            try client.status(at: staging.description)
        }
        guard entries.isEmpty else {
            throw .repository(
                "materialized tree diverges from \(revision.rawValue): "
                    + "\(entries.count) entry(ies) differ from the named commit"
            )
        }

        // Submodules are repository objects this materializer does not yet
        // reproduce: a gitlink checks out as an empty directory, which
        // would silently evaluate less source than the commit names.
        let modules = staging[file: ".gitmodules"]
        guard !File.System.Stat.exists(at: modules.path) else {
            throw .repository(
                "revision \(revision.rawValue) declares submodules, which exact "
                    + "materialization does not support; refusing rather than "
                    + "materializing less source than the commit names"
            )
        }

        return try execute { () throws(Git.Client.Error) in
            try client.tree(of: revision, at: staging.description)
        }
    }

    private func reference(_ value: Swift.String) throws(Institute.Error) -> Git.Ref.Name {
        do throws(Git.Ref.Name.Error) {
            return try Git.Ref.Name(value)
        } catch {
            throw .repository("invalid Git reference \(value): \(error)")
        }
    }

    private func execute<Result>(
        _ operation: () throws(Git.Client.Error) -> Result
    ) throws(Institute.Error) -> Result {
        do throws(Git.Client.Error) {
            return try operation()
        } catch {
            throw .process("Git operation failed: \(error)")
        }
    }
}
