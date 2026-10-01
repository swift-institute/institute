public import Institute_Model
public import Institute_CI_Model
public import JSON
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Inventory {
    /// The trust anchor: the sources a workflow revision is entitled to
    /// execute, pinned.
    ///
    /// While the CI sources lived in the same repository as the workflow
    /// that ran them, the anchor was implicit and free: a checkout at
    /// `job.workflow_sha` cannot differ from the workflow revision that
    /// invoked it, because they are the same commit. Once the sources own
    /// their own repositories that identity is gone — `job.workflow_sha`
    /// has no cross-repository counterpart — and "the sources this
    /// revision may execute" becomes a relation someone has to state.
    ///
    /// It is stated here, as literal commit pins with a recorded tree per
    /// source, and it is **generated**. A pin is an output of measuring a
    /// source repository, never a field a maintainer types: an
    /// authorable pin is a floating ref with extra steps, since nothing
    /// then connects the number in the file to a revision that was ever
    /// fetched. The recorded generator inputs and the shipped workflow
    /// are held together by a blocking correspondence check
    /// (`Institute.CI.Validation.Anchor`), which is
    /// the only thing that makes "generated" a fact rather than a
    /// convention.
    ///
    /// Four alternatives were considered and rejected in the ratified
    /// design (swift-institute/.github#461, Q3): floating refs (pin
    /// nothing); tags (the Institute mints none, so there is no tag
    /// authority to trust); submodules (a second, independently editable
    /// pin authority); and content-hash-only (a digest cannot say where
    /// to fetch from).
    ///
    /// **This type is the capability, not its activation.** Emitting the
    /// pinned steps into the universal workflow is a later, separate
    /// transaction; nothing here edits a workflow.
    public struct Anchor: Sendable, Equatable {
        /// Schema 1 — the first cross-repository shape. There is no
        /// schema 0: the arrangement this replaces recorded no manifest
        /// at all, because an in-repository anchor had nothing to record.
        public static let schemaVersion = 1

        /// What generated the pins. Provenance is a field rather than a
        /// comment because the correspondence check reports it: a
        /// disagreement between two producers is a different failure from
        /// a stale regeneration by one.
        public let producer: String

        /// The `actions/checkout` reference the generated steps use,
        /// itself identity-pinned. Recorded rather than hard-coded so
        /// advancing the checkout pin is an input change that regenerates
        /// the block, not an edit to this file.
        public let action: String

        /// The Actions condition both generated steps carry, when the
        /// consuming workflow guards them. Recorded for the same reason
        /// as `action`: generated output must equal shipped bytes, and a
        /// guard the generator does not know about would read as drift
        /// forever.
        public let condition: String?

        /// The pinned sources, in emission order.
        public let sources: [Source]

        public init(
            producer: String,
            action: String,
            condition: String? = nil,
            sources: [Source]
        ) throws(Institute.CI.Inventory.Error) {
            guard !sources.isEmpty else { throw .noSources }
            guard Self.isPinned(action) else { throw .unpinnedAction(action) }
            var seen: Set<String> = []
            for source in sources {
                guard seen.insert(source.repository).inserted else {
                    throw .duplicateSource(source.repository)
                }
            }
            self.producer = producer
            self.action = action
            self.condition = condition
            self.sources = sources
        }

        /// A `uses:` reference is pinned when its ref is a full object
        /// name. A tag or branch here would anchor the anchor to a
        /// mutable thing.
        public static func isPinned(_ reference: String) -> Bool {
            guard let separator = reference.lastIndex(of: "@") else { return false }
            return Revision.isCanonical(String(reference[reference.index(after: separator)...]))
        }

        /// The pinned source for a repository coordinate, if any.
        public func source(_ repository: String) -> Source? {
            sources.first { $0.repository == repository }
        }
    }
}

extension Institute.CI.Inventory.Anchor {
    /// The generated steps, in the order they must appear: for each
    /// source, the pinned checkout followed immediately by its identity
    /// check.
    ///
    /// The identity check is the half that survives a compromised
    /// coordinate. `actions/checkout` is trusted to fetch what it was
    /// asked for; the check asks git, in the workspace, what actually
    /// landed, and refuses when the answer differs from either recorded
    /// fact. It fails closed on a malformed answer too — an empty or
    /// non-canonical object name is a refusal, not a skip, because a
    /// comparison against nothing succeeds far too easily.
    public var steps: [Institute.CI.Workflow.YAML.Node] {
        sources.flatMap { [checkoutStep(for: $0), identityStep(for: $0)] }
    }

    /// The pinned checkout of one source.
    public func checkoutStep(
        for source: Source
    ) -> Institute.CI.Workflow.YAML.Node {
        var entries:
            [(
                key: Institute.CI.Workflow.YAML.Node,
                value: Institute.CI.Workflow.YAML.Node
            )] = [
                (.text("name"), .text(Self.checkoutName(of: source)))
            ]
        if let condition { entries.append((.text("if"), .text(condition))) }
        entries.append((.text("uses"), .text(action)))
        entries.append(
            (
                .text("with"),
                .mapping(
                    .init([
                        (.text("repository"), .text(source.repository)),
                        (.text("ref"), .text(source.commit.rawValue)),
                        (.text("path"), .text(source.checkout)),
                        (.text("persist-credentials"), .boolean(false)),
                    ])
                )
            )
        )
        return .mapping(.init(entries))
    }

    /// The in-job identity check of one source.
    public func identityStep(
        for source: Source
    ) -> Institute.CI.Workflow.YAML.Node {
        var entries:
            [(
                key: Institute.CI.Workflow.YAML.Node,
                value: Institute.CI.Workflow.YAML.Node
            )] = [
                (.text("name"), .text(Self.identityName(of: source)))
            ]
        if let condition { entries.append((.text("if"), .text(condition))) }
        entries.append((.text("id"), .text(Self.identityIdentifier(of: source))))
        entries.append((.text("shell"), .text("bash")))
        entries.append((.text("run"), .text(Self.script(for: source))))
        return .mapping(.init(entries))
    }

    /// The step name a source's checkout carries. Names are the join key
    /// the correspondence check locates a shipped step by, so they are
    /// derived from the repository and never authored.
    public static func checkoutName(of source: Source) -> String {
        "Checkout \(source.repository)"
    }

    /// The step name a source's identity check carries.
    public static func identityName(of source: Source) -> String {
        "\(source.repository) source identity"
    }

    /// The step id a source's identity check reports under.
    public static func identityIdentifier(of source: Source) -> String {
        "\(source.identifier)-identity"
    }

    /// One POSIX single-quoted shell word: the bytes of `value` as literal
    /// shell data, with each embedded `'` closed, escaped and reopened.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacing("'", with: "'\\''") + "'"
    }

    /// The identity check's shell body.
    public static func script(for source: Source) -> String {
        let directory = "\"${GITHUB_WORKSPACE}\"/\(Self.shellQuoted(source.checkout))"
        return """
            set -euo pipefail
            PINNED_COMMIT='\(source.commit.rawValue)'
            PINNED_TREE='\(source.tree.oid.rawValue)'
            PINNED_PATH=\(Self.shellQuoted(source.tree.path))
            ACTUAL_COMMIT="$(git -C \(directory) rev-parse HEAD)"
            ACTUAL_TREE="$(git -C \(directory) rev-parse \(Self.shellQuoted(source.tree.revision)))"
            for OID in "$ACTUAL_COMMIT" "$ACTUAL_TREE"; do
              [[ "$OID" =~ ^[0-9a-f]{40}$ ]] || { echo "::error::\(source.repository): refusing malformed object name '$OID'"; exit 1; }
            done
            [[ "$ACTUAL_COMMIT" == "$PINNED_COMMIT" ]] || { echo "::error::\(source.repository): checked-out commit '$ACTUAL_COMMIT' is not the pinned '$PINNED_COMMIT'. Refusing to execute unpinned CI sources."; exit 1; }
            [[ "$ACTUAL_TREE" == "$PINNED_TREE" ]] || { echo "::error::\(source.repository): tree of '$PINNED_PATH' is '$ACTUAL_TREE', pinned '$PINNED_TREE'. The commit resolved but its content did not."; exit 1; }
            echo "commit=$ACTUAL_COMMIT" >> "$GITHUB_OUTPUT"
            echo "tree=$ACTUAL_TREE" >> "$GITHUB_OUTPUT"

            """
    }
}

extension Institute.CI.Inventory.Anchor {
    public var node: Institute.CI.Workflow.YAML.Node {
        var entries:
            [(
                key: Institute.CI.Workflow.YAML.Node,
                value: Institute.CI.Workflow.YAML.Node
            )] = [
                (.text("schema_version"), .integer(Self.schemaVersion)),
                (.text("producer"), .text(producer)),
                (.text("action"), .text(action)),
            ]
        entries.append(
            (
                .text("condition"),
                condition.map(Institute.CI.Workflow.YAML.Node.text) ?? .null
            )
        )
        entries.append((.text("sources"), .sequence(sources.map(\.node))))
        return .mapping(.init(entries))
    }

    /// The anchor as canonical JSON — the manifest's own spelling, so a
    /// regenerated manifest and a recorded one compare directly.
    public var canonicalJSON: String {
        Institute.CI.Workflow.YAML.Canonical.json(node)
    }
}

extension Institute.CI.Inventory.Anchor {
    /// The anchor recorded in a manifest.
    ///
    /// Every way of not-knowing is a refusal. A missing member, a member
    /// of the wrong type, an object name that is not canonical, a
    /// `uses:` reference that is not pinned — each throws rather than
    /// defaulting, because a manifest that parses into a *partial* anchor
    /// would regenerate a partial block and the correspondence check
    /// would then agree with it.
    public init(manifest text: String) throws(Institute.CI.Inventory.Error) {
        // `JSON.parse` throws typed; its failure is exactly the refusal
        // raised below.
        let document: JSON
        do throws(JSON.Error) {
            document = try JSON.parse(text)
        } catch {
            throw .unreadableAnchor(message: "the manifest is not a JSON object")
        }
        guard let manifest = document.dictionary else {
            throw .unreadableAnchor(message: "the manifest is not a JSON object")
        }
        guard let version = manifest["schema_version"].flatMap({ Swift.Int($0) })
        else {
            throw .unreadableAnchor(message: "the manifest declares no integer `schema_version`")
        }
        guard version == Self.schemaVersion else {
            throw .unreadableAnchor(
                message: "the manifest declares schema \(version); this reader owns schema "
                    + "\(Self.schemaVersion)"
            )
        }
        guard let producer = Swift.String(manifest["producer"]) else {
            throw .unreadableAnchor(message: "the manifest declares no `producer` string")
        }
        guard let action = Swift.String(manifest["action"]) else {
            throw .unreadableAnchor(message: "the manifest declares no `action` string")
        }
        guard let recorded = manifest["sources"]?.array else {
            throw .unreadableAnchor(message: "the manifest declares no `sources` list")
        }
        let condition = Swift.String(manifest["condition"])

        var sources: [Source] = []
        for entry in recorded {
            guard let source = entry.dictionary else {
                throw .unreadableAnchor(message: "a `sources` entry is not an object")
            }
            guard let repository = Swift.String(source["repository"]) else {
                throw .unreadableAnchor(message: "a `sources` entry declares no `repository`")
            }
            guard let checkout = Swift.String(source["checkout"]) else {
                throw .unreadableAnchor(
                    message: "`\(repository)` declares no `checkout` path"
                )
            }
            guard let commit = Swift.String(source["commit"]) else {
                throw .unreadableAnchor(message: "`\(repository)` declares no `commit`")
            }
            guard let tree = source["tree"]?.dictionary,
                let treePath = Swift.String(tree["path"]),
                let treeOID = Swift.String(tree["oid"])
            else {
                throw .unreadableAnchor(
                    message: "`\(repository)` declares no `tree` object with `path` and `oid`"
                )
            }
            sources.append(
                Source(
                    repository: repository,
                    checkout: checkout,
                    commit: try Revision(commit),
                    tree: Source.Tree(path: treePath, oid: try Revision(treeOID))
                )
            )
        }
        try self.init(
            producer: producer,
            action: action,
            condition: condition,
            sources: sources
        )
    }
}
