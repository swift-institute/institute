import File_System
import Foundation
import JSON
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

extension Institute.Pages {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Pages.Test {
    /// Materializes `name`'s canonical checkout and writes `README.md` at
    /// its root, so the readme page's `present` field has something real
    /// to observe.
    static func materializeWithReadme(
        _ fixture: Institute.Doctor.Fixture,
        _ name: Swift.String,
        contents: Swift.String = "# Example\n"
    ) throws {
        try fixture.materialize(name)
        guard let repository = fixture.configuration.repositories.first(where: { $0.name == name })
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let location = try fixture.root.materialization(for: repository)
        try contents.write(
            toFile: location.description + "/README.md",
            atomically: true,
            encoding: .utf8
        )
    }

    static func writeDoccCatalogue(
        _ fixture: Institute.Doctor.Fixture,
        _ name: Swift.String,
        at relative: Swift.String
    ) throws {
        guard let repository = fixture.configuration.repositories.first(where: { $0.name == name })
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let location = try fixture.root.materialization(for: repository)
        let directory = location.description + "/" + relative
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
    }
}

extension Institute.Pages.Test.Unit {
    @Test
    func
        `Two enumerations over one fixture produce byte-identical canonical text and equal digests`()
        async throws
    {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        for repository in repositories {
            try Institute.Pages.Test.materializeWithReadme(fixture, repository.name)
        }

        let first = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )
        let second = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        #expect(first.canonical == second.canonical)
        let firstDigest = first.digest
        let secondDigest = second.digest
        #expect(firstDigest == secondDigest)
        #expect(firstDigest.count == 64)
        #expect(firstDigest.allSatisfy { $0.isHexDigit })

        let decoded = try Institute.Pages.Inventory(jsonString: first.canonical)
        #expect(decoded == first)
    }

    @Test
    func `A fixture whose roster order differs from sorted order produces the sorted inventory`()
        async throws
    {
        // Deliberately reverse-alphabetical input order.
        let repositories = [
            Institute.Repository(
                name: "swift-example-two",
                url: "https://github.com/swift-primitives/swift-example-two.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
            Institute.Repository(
                name: "swift-example-one",
                url: "https://github.com/swift-primitives/swift-example-one.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
        ]
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        for repository in repositories {
            try Institute.Pages.Test.materializeWithReadme(fixture, repository.name)
        }

        let inventory = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        #expect(inventory.repositories.map(\.name) == ["swift-example-one", "swift-example-two"])
    }

    @Test
    func `A fixture with two organizations inside one layer yields two organizationProfile pages`()
        async throws
    {
        let repositories = [
            Institute.Repository(
                name: "swift-example",
                url: "https://github.com/swift-primitives/swift-example.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
            Institute.Repository(
                name: "swift-example-vendor",
                url: "https://github.com/swift-intel/swift-example-vendor.git",
                organization: "swift-intel",
                layer: .primitives
            ),
        ]
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        for repository in repositories {
            try Institute.Pages.Test.materializeWithReadme(fixture, repository.name)
        }

        let inventory = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        #expect(inventory.organizationProfilePages.count == 2)
        #expect(
            Swift.Set(inventory.organizationProfilePages.map(\.organization))
                == ["swift-primitives", "swift-intel"]
        )
        #expect(inventory.organizationProfilePages.allSatisfy { $0.kind == .organizationProfile })
        #expect(inventory.organizationProfilePages.allSatisfy { $0.layer == nil })
        #expect(inventory.organizationProfilePages.allSatisfy { $0.name.isEmpty })
    }

    @Test
    func
        `A fixture with docc directories under .build and .swiftpm and one real catalogue yields exactly the real catalogue`()
        async throws
    {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        try Institute.Pages.Test.materializeWithReadme(fixture, "swift-example-one")
        try Institute.Pages.Test.materializeWithReadme(fixture, "swift-example-two")

        try Institute.Pages.Test.writeDoccCatalogue(
            fixture,
            "swift-example-one",
            at: "Sources/Example.docc"
        )
        try Institute.Pages.Test.writeDoccCatalogue(
            fixture,
            "swift-example-one",
            at: ".build/checkouts/Other.docc"
        )
        try Institute.Pages.Test.writeDoccCatalogue(
            fixture,
            "swift-example-one",
            at: ".swiftpm/configuration/Ignored.docc"
        )

        let inventory = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        let subject = inventory.repositories.first { $0.name == "swift-example-one" }
        let doccPages = subject?.pages.filter { $0.kind == .docc } ?? []
        #expect(doccPages.map(\.path) == ["Sources/Example.docc"])
        #expect(doccPages.allSatisfy { $0.present })
    }

    @Test
    func `A fixture with one absent repository yields that repository with its state and no pages`()
        async throws
    {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        // Only the first repository is materialized; the second is absent.
        try Institute.Pages.Test.materializeWithReadme(fixture, repositories[0].name)

        let inventory = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        let absent = inventory.repositories.first { $0.name == repositories[1].name }
        #expect(absent?.materialization == "absent")
        #expect(absent?.pages == [])
        #expect(!inventory.isFullyCanonical)
        #expect(inventory.nonCanonicalCounts["absent"] == 1)
    }

    @Test
    func `A narrowed selection records a non-policy selection value verbatim`() async throws {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(
            repositories: repositories,
            selected: [repositories[0]],
            origin: .overridden(
                committed: 2,
                added: [],
                removed: [
                    Institute.Repository.Key(
                        identity: "\(repositories[1].organization)/\(repositories[1].name)"
                    )!
                ]
            )
        )
        defer { fixture.remove() }
        try Institute.Pages.Test.materializeWithReadme(fixture, repositories[0].name)

        let inventory = await Institute.Pages.enumerate(
            root: fixture.root,
            selection: fixture.selection
        )

        #expect(inventory.instrument.selection != "policy")
        #expect(inventory.instrument.selection == "narrowed(+0/-1)")
    }
}
