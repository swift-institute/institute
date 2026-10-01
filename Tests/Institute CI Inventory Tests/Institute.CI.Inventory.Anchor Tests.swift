public import Institute_Model
import Institute_CI_Model
import Institute_CI_Workflow
import GitHub_Standard
import Testing

@testable import Institute_CI_Inventory

/// The trust anchor's model and emitter (ratified design Q3,
/// swift-institute/.github#461).
///
/// The correspondence gate's own suite proves the gate fires; this one
/// proves the thing it regenerates from is worth regenerating — that a
/// pin cannot be spelled as anything but a literal object name, that the
/// emitter is a function of its inputs alone, and that the advisory
/// report is structurally incapable of blocking.
@Suite
struct CIInventoryAnchorTests {
    typealias Anchor = Institute.CI.Inventory.Anchor

    static let commit = "0a1b2c3d4e5f60718293a4b5c6d7e8f901234567"
    static let tree = "1122334455667788990011223344556677889900"
    static let action = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"

    static func source(
        _ repository: String = "swift-foundations/swift-continuous-integration",
        commit: String = commit,
        path: String = "."
    ) throws -> Anchor.Source {
        Anchor.Source(
            repository: repository,
            checkout: ".ci-sources/"
                + (repository.split(separator: "/").last.map(String.init) ?? repository),
            commit: try Anchor.Revision(commit),
            tree: Anchor.Source.Tree(path: path, oid: try Anchor.Revision(Self.tree))
        )
    }

    static func anchor(_ sources: [Anchor.Source]) throws -> Anchor {
        try Anchor(producer: "institute-ci trust-anchor", action: action, sources: sources)
    }

    // MARK: - What counts as a pin

    @Suite
    struct Revisions {
        @Test func `a canonical object name is a revision`() throws {
            #expect(
                try Anchor.Revision(CIInventoryAnchorTests.commit).rawValue
                    == CIInventoryAnchorTests.commit
            )
        }

        /// Each of these is a perfectly good string and none of them pins
        /// anything: an abbreviation resolves, a ref moves, an expression
        /// resolves inside a run rather than in the file.
        @Test(
            arguments: [
                "0a1b2c3",
                "main",
                "v7.0.1",
                "${{ job.workflow_sha }}",
                "0A1B2C3D4E5F60718293A4B5C6D7E8F901234567",
                "0a1b2c3d4e5f60718293a4b5c6d7e8f9012345678",
                "0a1b2c3d4e5f60718293a4b5c6d7e8f90123456g",
                "",
            ])
        func `nothing but a canonical object name is accepted`(_ text: String) throws {
            #expect(throws: Institute.CI.Inventory.Error.malformedRevision(text))
            {
                try Anchor.Revision(text)
            }
        }
    }

    // MARK: - What counts as an anchor

    @Test func `an anchor pinning nothing is refused`() throws {
        #expect(throws: Institute.CI.Inventory.Error.noSources) {
            try Anchor(producer: "p", action: Self.action, sources: [])
        }
    }

    @Test func `an unpinned checkout action is refused`() throws {
        #expect(
            throws: Institute.CI.Inventory.Error
                .unpinnedAction("actions/checkout@v7")
        ) {
            try Anchor(producer: "p", action: "actions/checkout@v7", sources: [Self.source()])
        }
    }

    @Test func `one source pinned twice is refused`() throws {
        let repeated = try Self.source()
        #expect(
            throws: Institute.CI.Inventory.Error
                .duplicateSource(repeated.repository)
        ) {
            try Anchor(producer: "p", action: Self.action, sources: [repeated, repeated])
        }
    }

    // MARK: - Emission

    @Test func `each source emits its checkout followed by its identity check`() throws {
        let anchor = try Self.anchor([
            Self.source(),
            Self.source(
                "swift-institute/institute-continuous-integration",
                commit: "fedcba9876543210fedcba9876543210fedcba98"
            ),
        ])
        let names = anchor.steps.compactMap { $0["name"]?.text }
        #expect(
            names == [
                "Checkout swift-foundations/swift-continuous-integration",
                "swift-foundations/swift-continuous-integration source identity",
                "Checkout swift-institute/institute-continuous-integration",
                "swift-institute/institute-continuous-integration source identity",
            ]
        )
    }

    @Test func `the checkout is pinned to the literal commit and carries no credentials`() throws {
        let source = try Self.source()
        let step = try Self.anchor([source]).checkoutStep(for: source)
        #expect(step["uses"]?.text == Self.action)
        #expect(step["with"]?["ref"]?.text == Self.commit)
        #expect(step["with"]?["repository"]?.text == source.repository)
        #expect(step["with"]?["persist-credentials"]?.boolean == false)
    }

    /// Both recorded facts appear in the check, and the tree is read as
    /// the root tree when the source repository *is* the package.
    @Test func `the identity check compares both recorded facts`() throws {
        let source = try Self.source()
        let script = try #require(Self.anchor([source]).identityStep(for: source)["run"]?.text)
        #expect(script.contains("PINNED_COMMIT='\(Self.commit)'"))
        #expect(script.contains("PINNED_TREE='\(Self.tree)'"))
        #expect(script.contains("rev-parse HEAD"))
        #expect(script.contains("rev-parse 'HEAD^{tree}'"))
        #expect(script.contains("exit 1"))
    }

    /// The workspace is expanded by the shell and the checkout is literal
    /// data: `${GITHUB_WORKSPACE}` sits in double quotes, the checkout in
    /// single quotes.
    @Test func `the identity check expands the workspace and quotes the checkout`() throws {
        let source = try Self.source()
        let script = try #require(Self.anchor([source]).identityStep(for: source)["run"]?.text)
        #expect(
            script.contains(
                #"ACTUAL_COMMIT="$(git -C "${GITHUB_WORKSPACE}"/'.ci-sources/swift-continuous-integration' rev-parse HEAD)""#
            )
        )
        #expect(
            script.contains(
                #"ACTUAL_TREE="$(git -C "${GITHUB_WORKSPACE}"/'.ci-sources/swift-continuous-integration' rev-parse 'HEAD^{tree}')""#
            )
        )
        #expect(script.contains("PINNED_PATH='.'"))
        #expect(!script.contains("'${GITHUB_WORKSPACE}"))
    }

    /// A narrower subtree keeps the pre-flip spelling, so a pin can
    /// describe the arrangement it replaces.
    @Test func `a subtree pin reads that subtree, not the root`() throws {
        let source = try Self.source(path: "Tools/institute-ci")
        let script = try #require(Self.anchor([source]).identityStep(for: source)["run"]?.text)
        #expect(script.contains("rev-parse 'HEAD:Tools/institute-ci'"))
        #expect(!script.contains("HEAD^{tree}"))
    }

    @Test func `a guarded anchor puts its condition on both generated steps`() throws {
        let source = try Self.source()
        let anchor = try Anchor(
            producer: "institute-ci trust-anchor",
            action: Self.action,
            condition: "${{ inputs.job == '' }}",
            sources: [source]
        )
        #expect(anchor.steps.allSatisfy { $0["if"]?.text == "${{ inputs.job == '' }}" })
    }

    /// The emitter is a function of its inputs. If it were not, the
    /// correspondence gate would report drift on an unchanged manifest.
    @Test func `emission is deterministic`() throws {
        let anchor = try Self.anchor([Self.source()])
        #expect(anchor.steps == anchor.steps)
        #expect(anchor.canonicalJSON == anchor.canonicalJSON)
    }

    /// The step id is derived from the coordinate, so two sources cannot
    /// be handed the same one.
    @Test func `step ids are derived from the repository name`() throws {
        #expect(try Self.source().identifier == "swift-continuous-integration")
    }

    // MARK: - The manifest

    @Test func `a recorded manifest round-trips through the model`() throws {
        let anchor = try Self.anchor([Self.source()])
        let recovered = try Anchor(manifest: anchor.canonicalJSON)
        #expect(recovered == anchor)
        #expect(recovered.steps == anchor.steps)
    }

    @Test(
        arguments: [
            ("{ not json", "not a JSON object"),
            (#"{"schema_version": 2}"#, "schema 2"),
            (#"{"schema_version": 1}"#, "`producer`"),
            (#"{"schema_version": 1, "producer": "p"}"#, "`action`"),
        ])
    func `a manifest that cannot be read is refused, never partially read`(
        _ text: String,
        _ expected: String
    ) throws {
        do throws(Institute.CI.Inventory.Error) {
            _ = try Anchor(manifest: text)
            Issue.record("a manifest missing \(expected) was accepted")
        } catch {
            #expect(error.message.contains(expected))
        }
    }

    // MARK: - The advisory report

    /// Advisory is structural, not a promise: the report has no rule, no
    /// finding, and no registry entry, and this is the constant that says
    /// so.
    @Test func `the staleness report is never blocking`() {
        #expect(Anchor.Staleness.isBlocking == false)
    }

    @Test func `a pin equal to the observed tip is current`() throws {
        let anchor = try Self.anchor([Self.source()])
        let report = Anchor.Staleness(
            anchor: anchor,
            observed: [
                .init(
                    repository: "swift-foundations/swift-continuous-integration",
                    head: try Anchor.Revision(Self.commit),
                    distance: 0
                )
            ]
        )
        #expect(report.behind.isEmpty)
        #expect(report.unmeasured.isEmpty)
        #expect(report.rows.first?.isCurrent == true)
    }

    @Test func `a pin behind the observed tip is reported with its distance`() throws {
        let anchor = try Self.anchor([Self.source()])
        let report = Anchor.Staleness(
            anchor: anchor,
            observed: [
                .init(
                    repository: "swift-foundations/swift-continuous-integration",
                    head: try Anchor.Revision("fedcba9876543210fedcba9876543210fedcba98"),
                    distance: 12
                )
            ]
        )
        #expect(report.behind.count == 1)
        #expect(report.behind.first?.distance == 12)
        #expect(report.rows.first?.isCurrent == false)
    }

    /// The state that matters: nobody looked. Unmeasured is neither
    /// current nor behind, because a report that rendered an unobserved
    /// pin as up to date would be worse than no report.
    @Test func `an unobserved source is unmeasured, not current`() throws {
        let report = Anchor.Staleness(anchor: try Self.anchor([Self.source()]), observed: [])
        #expect(report.unmeasured.count == 1)
        #expect(report.behind.isEmpty)
        let row = try #require(report.rows.first)
        #expect(!row.isMeasured)
        #expect(!row.isCurrent)
    }

    /// An observation for a repository the anchor does not pin has no pin
    /// to be a distance from.
    @Test func `an observation of an unpinned repository contributes nothing`() throws {
        let report = Anchor.Staleness(
            anchor: try Self.anchor([Self.source()]),
            observed: [
                .init(
                    repository: "swift-institute/unrelated",
                    head: try Anchor.Revision(Self.tree),
                    distance: 3
                )
            ]
        )
        #expect(report.rows.count == 1)
        #expect(report.rows.first?.repository == "swift-foundations/swift-continuous-integration")
        #expect(report.unmeasured.count == 1)
    }
}

#if !os(Windows)
/// The emitted identity script, executed with bash against an owned local
/// Git checkout. The object names are the fixture's own; nothing is
/// fetched and no workflow runs.
@Suite(.serialized)
struct CIInventoryAnchorShellTests {
    typealias Anchor = Institute.CI.Inventory.Anchor

    static func script(
        checkout: String,
        commit: String,
        tree: String,
        path: String = "."
    ) throws -> String {
        Anchor.script(
            for: Anchor.Source(
                repository: "swift-foundations/swift-continuous-integration",
                checkout: checkout,
                commit: try Anchor.Revision(commit),
                tree: Anchor.Source.Tree(path: path, oid: try Anchor.Revision(tree))
            )
        )
    }

    @Test func `a matching commit and tree succeed with both outputs`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let pinned = try fixture.repository(at: ".ci-sources/swift-continuous-integration")
        let run = try fixture.execute(
            Self.script(
                checkout: ".ci-sources/swift-continuous-integration",
                commit: pinned.commit,
                tree: pinned.tree
            )
        )
        #expect(run.status == 0)
        #expect(run.output == "commit=\(pinned.commit)\ntree=\(pinned.tree)\n")
    }

    @Test func `a subtree pin succeeds against that subtree`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let pinned = try fixture.repository(at: ".ci-sources/swift-continuous-integration")
        let run = try fixture.execute(
            Self.script(
                checkout: ".ci-sources/swift-continuous-integration",
                commit: pinned.commit,
                tree: pinned.subtree,
                path: "Tools/institute-ci"
            )
        )
        #expect(run.status == 0)
        #expect(run.output == "commit=\(pinned.commit)\ntree=\(pinned.subtree)\n")
    }

    @Test func `a mismatched commit is refused`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let pinned = try fixture.repository(at: ".ci-sources/swift-continuous-integration")
        let run = try fixture.execute(
            Self.script(
                checkout: ".ci-sources/swift-continuous-integration",
                commit: "0a1b2c3d4e5f60718293a4b5c6d7e8f901234567",
                tree: pinned.tree
            )
        )
        #expect(run.status == 1)
        #expect(run.standardOutput.contains("is not the pinned '0a1b2c3d4e5f60718293a4b5c6d7e8f901234567'"))
        #expect(run.output.isEmpty)
    }

    @Test func `a mismatched tree is refused`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let pinned = try fixture.repository(at: ".ci-sources/swift-continuous-integration")
        let run = try fixture.execute(
            Self.script(
                checkout: ".ci-sources/swift-continuous-integration",
                commit: pinned.commit,
                tree: "1122334455667788990011223344556677889900"
            )
        )
        #expect(run.status == 1)
        #expect(run.standardOutput.contains("tree of '.' is '\(pinned.tree)'"))
        #expect(run.output.isEmpty)
    }

    @Test func `an absent checkout fails closed`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let run = try fixture.execute(
            Self.script(
                checkout: ".ci-sources/swift-continuous-integration",
                commit: "0a1b2c3d4e5f60718293a4b5c6d7e8f901234567",
                tree: "1122334455667788990011223344556677889900"
            )
        )
        #expect(run.status != 0)
        #expect(run.output.isEmpty)
    }

    /// The single-quote escape itself, executed: a checkout path with an
    /// embedded `'` is emitted as `'…'\''…'` and still names that
    /// directory, so both recorded facts verify against it.
    @Test func `a checkout path with an embedded single quote verifies through its escape`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let checkout = ".ci-sources/o'brien"
        let pinned = try fixture.repository(at: checkout)
        let script = try Self.script(checkout: checkout, commit: pinned.commit, tree: pinned.tree)
        #expect(script.contains(#""${GITHUB_WORKSPACE}"/'.ci-sources/o'\''brien' rev-parse HEAD"#))
        let run = try fixture.execute(script)
        #expect(run.status == 0)
        #expect(run.output == "commit=\(pinned.commit)\ntree=\(pinned.tree)\n")
        #expect(fixture.exists(checkout + "/.git"))
    }

    @Test func `a spaced, quoted checkout path is literal data, never executed`() throws {
        let fixture = try AnchorShellFixture()
        defer { fixture.remove() }
        let checkout = "ci sources/it's $(touch executed) `touch executed`"
        let pinned = try fixture.repository(at: checkout)
        let run = try fixture.execute(
            Self.script(checkout: checkout, commit: pinned.commit, tree: pinned.tree)
        )
        #expect(run.status == 0)
        #expect(run.output == "commit=\(pinned.commit)\ntree=\(pinned.tree)\n")
        #expect(!fixture.exists("executed"))
    }
}
#endif
