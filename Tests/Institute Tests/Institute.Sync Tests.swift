import File_System
import Foundation
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Sync {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Sync.Test.Integration {
    private static func selectedAuthority(
        _ fixture: Institute.Sync.Fixture
    ) throws -> Institute.Sync {
        let repository = Institute.Repository(
            name: "swift-rfc-0000",
            url: fixture.remote.path,
            organization: "swift-ietf",
            layer: .standards
        )
        return Institute.Sync(
            root: try Institute.Root(checkout: File.Directory(validating: fixture.root.path)),
            selection: .init(repositories: [repository], origin: .committed(count: 1)),
            client: fixture.client
        )
    }

    @Test
    func `Dry run changes neither canonical checkout metadata nor checkout owned files`() throws {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.push("second", contents: "second\n")
        let before = try fixture.state()

        try fixture.application().run(dry: true)

        #expect(try fixture.state() == before)
        #expect(try fixture.residue().isEmpty)
    }

    @Test
    func
        `Force pushed remote leaves local repository untouched while publishing the checkout workspace`()
        throws
    {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.replaceRemote()
        let before = try fixture.state()

        try fixture.application().run(dry: false)

        let after = try fixture.state()
        #expect(after.head == before.head)
        #expect(after.origin == before.origin)
        #expect(after.fetch == before.fetch)
        #expect(after.status == before.status)
        #expect(after.canonical == before.canonical)
        #expect(after.legacy == before.legacy)
        #expect(after.ledger == before.ledger)
        #expect(after.workspace != nil)
        #expect(try fixture.residue().isEmpty)
    }

    @Test
    func `a regular directory at the canonical target stops sync before workspace publication`()
        throws
    {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        let collision = fixture.base.appending(path: "swift-standards/swift-ietf/swift-rfc-0000")
        try FileManager.default.createDirectory(at: collision, withIntermediateDirectories: true)
        let marker = collision.appending(path: "marker")
        try Data("collision".utf8).write(to: marker)

        #expect(throws: Institute.Error.self) {
            try Self.selectedAuthority(fixture).run(dry: false)
        }

        #expect(try Data(contentsOf: marker) == Data("collision".utf8))
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root.appending(path: "institute.xcworkspace").path
            )
        )
    }

    @Test
    func `a symbolic sibling prefix stops sync without writing through the link`() throws {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        let outside = fixture.base.appending(path: "outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: fixture.base.appending(path: "swift-standards"),
            withDestinationURL: outside
        )

        #expect(throws: Institute.Error.self) {
            try Self.selectedAuthority(fixture).run(dry: false)
        }

        #expect(
            !FileManager.default.fileExists(
                atPath: outside.appending(path: "swift-ietf/swift-rfc-0000").path
            )
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root.appending(path: "institute.xcworkspace").path
            )
        )
    }

    @Test
    func
        `A resolved selection clones only its authority repository and renders only that reference`()
        throws
    {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        let selected = Institute.Repository(
            name: "swift-rfc-0000",
            url: fixture.remote.path,
            organization: "swift-ietf",
            layer: .standards
        )
        let unselected = Institute.Repository(
            name: "swift-unused",
            url: "https://github.com/swift-foundations/swift-unused.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let root = try File.Directory(validating: fixture.root.path)
        let sync = Institute.Sync(
            root: try Institute.Root(checkout: root),
            selection: .init(repositories: [selected], origin: .committed(count: 1)),
            client: fixture.client
        )

        try sync.run(dry: false)

        let cloned = fixture.base.appending(
            path: "swift-standards/swift-ietf/swift-rfc-0000/.git"
        )
        #expect(FileManager.default.fileExists(atPath: cloned.path))
        let excluded = fixture.base.appending(
            path: Institute.Layout.reference(for: unselected)
        )
        #expect(!FileManager.default.fileExists(atPath: excluded.path))
        let workspace = try #require(Institute.Xcode.contents(at: root))
        #expect(workspace.contains("../\(Institute.Layout.reference(for: selected))"))
        #expect(!workspace.contains("../\(Institute.Layout.reference(for: unselected))"))
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root.appending(path: Institute.Layout.reference(for: selected)).path
            )
        )
    }

    @Test
    func `Proven descendant fast forwards local main`() throws {
        let fixture = try Institute.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.push("second", contents: "second\n")
        let before = try fixture.state()

        try fixture.application().run(dry: false)

        let after = try fixture.state()
        #expect(after.head != before.head)
        #expect(after.head == after.origin)
        #expect(after.status.isEmpty)
        #expect(try fixture.residue().isEmpty)
    }

    /// `inspect`'s origin check must agree with `sameRepository`/`displaced`
    /// on transport spelling — a live control proved the two owners disagreed
    /// (swift-institute/institute-application#201): raw `==` failed 9
    /// checkouts whose `origin` was SSH against `Institute.json`'s canonical
    /// HTTPS URL.
    ///
    /// Each fixture parks `local` on a non-`main` branch before rewriting
    /// `origin`, so a passing origin check is provably observed at the next
    /// gate — the branch check's `.skip` — without requiring the synthetic
    /// `repository.url` used here to be a reachable remote for `probe`/`fetch`.
    private static func originCheck(
        origin: Swift.String,
        canonical: Swift.String
    ) throws -> Institute.Sync {
        let fixture = try Institute.Sync.Fixture()
        try fixture.checkout("not-main")
        try fixture.setOrigin(origin)
        let repository = Institute.Repository(
            name: "swift-example",
            url: canonical,
            organization: "swift-foundations",
            layer: .foundations
        )
        return Institute.Sync(
            root: try Institute.Root(checkout: File.Directory(validating: fixture.root.path)),
            selection: .init(repositories: [repository], origin: .committed(count: 1)),
            client: fixture.client
        )
    }

    @Test
    func `scp-style SSH origin against the canonical HTTPS URL is not a conflict`() throws {
        let sync = try Self.originCheck(
            origin: "git@github.com:swift-foundations/swift-example.git",
            canonical: "https://github.com/swift-foundations/swift-example.git"
        )

        try sync.run(dry: true)
    }

    @Test
    func `ssh scheme origin against the canonical HTTPS URL is not a conflict`() throws {
        let sync = try Self.originCheck(
            origin: "ssh://git@github.com/swift-foundations/swift-example.git",
            canonical: "https://github.com/swift-foundations/swift-example.git"
        )

        try sync.run(dry: true)
    }

    /// The negative control: a genuinely different repository must still
    /// produce `.fail`, proving `sameRepository` didn't loosen `inspect`'s
    /// origin check into uselessness — it only removed the transport-spelling
    /// false positive. `run(dry:)` throws before any mutation whenever a
    /// planned inspection is fatal (`Institute.Action.fatal`), which is
    /// exactly `.fail`, so a throw here is a direct observation of that case.
    ///
    /// This doesn't re-capture the `.fail` reason text: `run(dry:)` prints
    /// each inspection's `Action.text` concurrently with every other test in
    /// this (parallel-by-default) suite, so redirecting the process-global
    /// `stdout` here would race arbitrary other tests' output. The reason
    /// string itself — `"origin is \(remote), expected \(repository.url)"` —
    /// is unchanged by this fix; only the guard's comparison operator moved
    /// from `==` to `Self.sameRepository`, and `sameRepository` distinguishing
    /// genuinely different repositories is already covered directly by
    /// `Institute Sync Displaced Tests`.
    @Test
    func `an origin naming a genuinely different repository still conflicts`() throws {
        let sync = try Self.originCheck(
            origin: "git@github.com:swift-foundations/swift-other.git",
            canonical: "https://github.com/swift-foundations/swift-example.git"
        )

        #expect(throws: Institute.Error.self) {
            try sync.run(dry: true)
        }
    }
}
