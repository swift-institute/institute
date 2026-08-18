import File_System
import Foundation
import Package_Manager
import SPM_Standard
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Composition.SourceMap {
    @Suite
    struct Test {}
}

extension Institute.Composition.SourceMap.Test {
    /// One disposable fixture hierarchy: a temp checkout, a temp root
    /// registered as hierarchy `main`, and materialized repository
    /// directories with `Package.swift` markers. Evaluation is
    /// fixture-injected — no SwiftPM is spawned.
    private struct Fixture {
        let checkout: File.Directory
        let root: File.Directory
        let hierarchy: Institute.Hierarchy.ID
        var evaluations: [Swift.String: Package.Manifest.Evaluation] = [:]

        init() throws {
            let base = FileManager.default.temporaryDirectory
                .resolvingSymlinksInPath()
                .appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(
                at: base.appending(path: "checkout"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: base.appending(path: "root"),
                withIntermediateDirectories: true
            )
            self.checkout = try File.Directory(validating: base.appending(path: "checkout").path)
            self.root = File.Directory(
                try File.System.Canonical.resolve(
                    File.Path(base.appending(path: "root").path)
                )
            )
            self.hierarchy = try Institute.Hierarchy.ID("main")
            try Institute.Hierarchy.Registry.register(
                id: hierarchy,
                locator: root,
                ownership: .adopted,
                at: checkout
            )
        }

        func tearDown() {
            guard let parent = checkout.path.parent else { return }
            try? FileManager.default.removeItem(atPath: parent.description)
        }

        static func repository(_ name: Swift.String) -> Institute.Repository {
            .init(
                name: name,
                url: "https://github.com/swift-primitives/\(name).git",
                organization: "swift-primitives",
                layer: .primitives
            )
        }

        /// Materializes `repository` under the fixture root with a
        /// `Package.swift` marker and records its fixture evaluation.
        mutating func materialize(
            _ repository: Institute.Repository,
            name: Swift.String? = nil,
            dependencies: [Swift.String] = []
        ) throws {
            let directory = try Institute.Layout.directory(for: repository, at: root)
            try FileManager.default.createDirectory(
                atPath: directory.path.description,
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(
                atPath: directory[file: "Package.swift"].path.description,
                contents: Data("// fixture manifest\n".utf8)
            )
            evaluations[directory.description] = .init(
                name: .init(name ?? repository.name),
                toolsVersion: .init(major: .init(6), minor: .init(3)),
                dependencies: dependencies.map { identity in
                    .init(
                        source: .sourceControl(
                            identity: .init(identity),
                            location: .local(path: "/fixtures/\(identity)"),
                            requirement: .branch("main")
                        )
                    )
                }
            )
        }

        func evaluate(
            _ directory: Swift.String
        ) throws(Package.Manager.Error) -> Package.Manifest.Evaluation {
            guard let evaluation = evaluations[directory] else { throw .manifest }
            return evaluation
        }
    }

    @Test
    func `explicit seeds normalize to their forward closure in reference order`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        let b = Fixture.repository("swift-b-primitives")
        let c = Fixture.repository("swift-c-primitives")
        try fixture.materialize(a, dependencies: ["swift-c-primitives"])
        try fixture.materialize(b)
        try fixture.materialize(c)

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        let entries = try map.normalized(
            scope: .seeds(["swift-a-primitives"]),
            roster: [a, b, c],
            at: fixture.checkout,
            evaluate: fixture.evaluate
        )
        #expect(entries.map(\.repository.name) == ["swift-a-primitives", "swift-c-primitives"])
        #expect(entries.allSatisfy { $0.hierarchy == fixture.hierarchy })
    }

    @Test
    func `full-inventory scope equals the roster exactly`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        let b = Fixture.repository("swift-b-primitives")
        try fixture.materialize(a)
        try fixture.materialize(b)

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        let entries = try map.normalized(
            scope: .inventory,
            roster: [b, a],
            at: fixture.checkout,
            evaluate: fixture.evaluate
        )
        #expect(entries.map(\.repository.name) == ["swift-a-primitives", "swift-b-primitives"])
    }

    @Test
    func `an empty explicit seed selection fails`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }
        _ = fixture

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try map.normalized(
                scope: .seeds([]),
                roster: [],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }
    }

    @Test
    func `an unknown seed fails`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }
        _ = fixture

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try map.normalized(
                scope: .seeds(["swift-unknown-primitives"]),
                roster: [Fixture.repository("swift-a-primitives")],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }
    }

    @Test
    func `an unknown or out-of-scope override fails`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        let b = Fixture.repository("swift-b-primitives")
        try fixture.materialize(a)
        try fixture.materialize(b)

        let unknown = Institute.Composition.SourceMap(
            defaultHierarchy: fixture.hierarchy,
            overrides: ["swift-nowhere-primitives": fixture.hierarchy]
        )
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try unknown.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a, b],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }

        let outOfScope = Institute.Composition.SourceMap(
            defaultHierarchy: fixture.hierarchy,
            overrides: ["swift-b-primitives": fixture.hierarchy]
        )
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try outOfScope.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a, b],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }
    }

    @Test
    func `a repository can be explicitly assigned to a second hierarchy`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let secondBase = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: secondBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: secondBase) }
        let secondRoot = File.Directory(
            try File.System.Canonical.resolve(File.Path(secondBase.path))
        )
        let second = try Institute.Hierarchy.ID("second")
        try Institute.Hierarchy.Registry.register(
            id: second,
            locator: secondRoot,
            ownership: .adopted,
            at: fixture.checkout
        )

        let a = Fixture.repository("swift-a-primitives")
        let b = Fixture.repository("swift-b-primitives")
        try fixture.materialize(a, dependencies: ["swift-b-primitives"])

        let bDirectory = try Institute.Layout.directory(for: b, at: secondRoot)
        try FileManager.default.createDirectory(
            atPath: bDirectory.path.description,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: bDirectory[file: "Package.swift"].path.description,
            contents: Data("// fixture manifest\n".utf8)
        )
        fixture.evaluations[bDirectory.description] = .init(
            name: .init("swift-b-primitives"),
            toolsVersion: .init(major: .init(6), minor: .init(3))
        )

        let map = Institute.Composition.SourceMap(
            defaultHierarchy: fixture.hierarchy,
            overrides: ["swift-b-primitives": second]
        )
        let entries = try map.normalized(
            scope: .seeds(["swift-a-primitives"]),
            roster: [a, b],
            at: fixture.checkout,
            evaluate: fixture.evaluate
        )
        #expect(entries.count == 2)
        let assigned = try #require(entries.first { $0.repository.name == "swift-b-primitives" })
        #expect(assigned.hierarchy == second)
        #expect(assigned.directory == bDirectory)
    }

    @Test
    func `a missing manifest fails, never a silent omission`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        let directory = try Institute.Layout.directory(for: a, at: fixture.root)
        try FileManager.default.createDirectory(
            atPath: directory.path.description,
            withIntermediateDirectories: true
        )

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try map.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }
    }

    @Test
    func `identity divergence reports the reference and the evaluated identity`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        try fixture.materialize(a, name: "swift-divergent-primitives")

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        do {
            _ = try map.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
            Issue.record("divergence was accepted")
        } catch {
            guard case .identityDivergence(let reference, let evaluated) = error else {
                Issue.record("unexpected error \(error)")
                return
            }
            #expect(reference == "swift-a-primitives")
            #expect(evaluated == "swift-divergent-primitives")
        }
    }

    @Test
    func `a governed-organization dependency outside the population fails closed`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        try fixture.materialize(a)
        let location = try Package.Dependency.Evaluation.Source.Location.remote(
            .init("https://github.com/swift-primitives/swift-tls.git")
        )
        fixture.evaluations = fixture.evaluations.mapValues { evaluation in
            .init(
                name: evaluation.name,
                toolsVersion: evaluation.toolsVersion,
                dependencies: [
                    .init(
                        source: .sourceControl(
                            identity: .init("swift-tls"),
                            location: location,
                            requirement: .branch("main")
                        )
                    )
                ]
            )
        }

        let map = Institute.Composition.SourceMap(defaultHierarchy: fixture.hierarchy)
        do {
            _ = try map.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
            Issue.record("governed out-of-population edge was accepted as external")
        } catch {
            guard case .populationIntegrity(let reference, let identity, let organization) = error
            else {
                Issue.record("unexpected error \(error)")
                return
            }
            #expect(reference == "swift-a-primitives")
            #expect(identity == "swift-tls")
            #expect(organization == "swift-primitives")
        }
    }

    @Test
    func `an unregistered hierarchy fails closed`() throws {
        var fixture = try Fixture()
        defer { fixture.tearDown() }

        let a = Fixture.repository("swift-a-primitives")
        try fixture.materialize(a)

        let map = Institute.Composition.SourceMap(
            defaultHierarchy: try Institute.Hierarchy.ID("unregistered")
        )
        #expect(throws: Institute.Composition.SourceMap.Error.self) {
            _ = try map.normalized(
                scope: .seeds(["swift-a-primitives"]),
                roster: [a],
                at: fixture.checkout,
                evaluate: fixture.evaluate
            )
        }
    }
}
