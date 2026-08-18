public import File_System
public import Git_Foundation
public import Institute_Model

extension Institute.Certification {
    /// Derives one exact snapshot from the materialized fleet — the
    /// fail-closed counterpart of the coherence instrument's best-effort
    /// advisory heads map.
    ///
    /// Every inventory repository becomes a package member at the exact
    /// revision its materialized checkout's `main` names, or is covered by
    /// an explicit typed exclusion, or derivation fails. Silent omission is
    /// unrepresentable: an unreadable member that nobody excluded stops the
    /// derivation with the owning identity in the error.
    ///
    /// Central control-plane members are an explicit input, never inferred:
    /// the control plane names them (`swift-institute/.github#627`), and
    /// their revisions arrive pre-read because their checkouts live outside
    /// the inventory materialization tree.
    ///
    /// The head reader is injected with a real default — the module's
    /// `tool`/`environment` pattern — so a test substitutes a fake without
    /// a Git checkout while production always reads the real repository.
    public struct Derivation: Sendable {
        public let root: Institute.Root
        public let configuration: Institute.Configuration

        public let head:
            @Sendable (Institute.Root, Institute.Repository) throws(Institute.Error) ->
                Revision

        public init(
            root: Institute.Root,
            configuration: Institute.Configuration,
            git: Git.Client = .init(),
            head: (
                @Sendable (Institute.Root, Institute.Repository) throws(Institute.Error) ->
                    Revision
            )? = nil
        ) {
            self.root = root
            self.configuration = configuration
            // Branching rather than `??`: the 6.4 frontend crashes in
            // IRGen lowering the implicit autoclosure around a
            // typed-throws `@Sendable` closure default.
            if let head {
                self.head = head
            } else {
                self.head = { root, repository throws(Institute.Error) in
                    try Self.materializedHead(git: git, root: root, repository: repository)
                }
            }
        }

        // Internal rather than private: ``Institute/Certification/Execution``
        // shares the same exact-head read for its materialization proof.
        internal static func materializedHead(
            git: Git.Client,
            root: Institute.Root,
            repository: Institute.Repository
        ) throws(Institute.Error) -> Revision {
            let directory: File.Directory
            do throws(Institute.Error) {
                directory = try root.materialization(for: repository)
            } catch {
                throw .repository(
                    "\(repository.organization)/\(repository.name): "
                        + "no readable materialization: \(error.description)"
                )
            }
            let object: Git.Object.ID
            do throws(Git.Client.Error) {
                object = try git.head("main", at: directory.description)
            } catch {
                throw .repository(
                    "\(repository.organization)/\(repository.name): "
                        + "head of main is unreadable"
                )
            }
            do throws(Institute.Error) {
                return try Revision(object.rawValue)
            } catch {
                throw .repository(
                    "\(repository.organization)/\(repository.name): "
                        + "head is not a full revision: \(object.rawValue)"
                )
            }
        }
    }
}

extension Institute.Certification.Derivation {
    /// Derive the snapshot: every inventory repository at its exact
    /// materialized `main` revision, plus the named central members, minus
    /// the explicit typed exclusions.
    public func snapshot(
        inventoryCommit: Institute.Certification.Revision,
        inventoryBlob: Swift.String,
        centrals: [Institute.Repository.Key: Institute.Certification.Revision],
        exclusions: [Institute.Certification.Exclusion]
    ) throws(Institute.Error) -> Institute.Certification.Snapshot {
        let excluded = Set(exclusions.map(\.key))
        var members = [Institute.Certification.Member]()
        for repository in configuration.repositories {
            guard let key = Institute.Repository.Key(repository: repository) else {
                throw .repository(
                    "\(repository.organization)/\(repository.name): "
                        + "inventory identity is not a canonical repository key"
                )
            }
            if excluded.contains(key) { continue }
            members.append(
                .init(
                    key: key,
                    revision: try head(root, repository),
                    kind: .package(layer: repository.layer)
                )
            )
        }
        for (key, revision) in centrals {
            guard !excluded.contains(key) else { continue }
            members.append(.init(key: key, revision: revision, kind: .controlPlane))
        }
        return try .init(
            inventoryCommit: inventoryCommit,
            inventoryBlob: inventoryBlob,
            members: members,
            exclusions: exclusions
        )
    }
}
