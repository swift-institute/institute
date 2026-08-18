import File_System
import Foundation
import Package_Manager
import SPM_Standard
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Composition.BuildPlan {
    @Suite
    struct Test {}
}

extension Institute.Composition.BuildPlan.Test {
    private static func package(
        _ identity: Swift.String,
        reference: Swift.String? = nil,
        libraries: [Swift.String] = ["Library"],
        targets: Swift.Int = 1
    ) -> Institute.Composition.BuildPlan.Package {
        .init(
            identity: identity,
            reference: reference ?? "../swift-primitives/\(identity)",
            libraryProducts: libraries,
            buildableTargetCount: targets
        )
    }

    @Test
    func `the same plan renders byte-identically and in deterministic order`() throws {
        let plan = try Institute.Composition.BuildPlan(
            seeds: ["swift-b-primitives", "swift-a-primitives"],
            packages: [
                Self.package("swift-b-primitives", targets: 2),
                Self.package("swift-a-primitives", libraries: ["A One", "A Two"]),
            ]
        )
        let first = Institute.Composed.Root.render(plan, swift: "6.3.3")
        let second = Institute.Composed.Root.render(plan, swift: "6.3.3")
        #expect(first == second)
        #expect(plan.seeds == ["swift-a-primitives", "swift-b-primitives"])
        #expect(plan.packages.map(\.identity) == ["swift-a-primitives", "swift-b-primitives"])

        let aIndex = try #require(first.range(of: "swift-a-primitives")).lowerBound
        let bIndex = try #require(first.range(of: "swift-b-primitives")).lowerBound
        #expect(aIndex < bIndex)
    }

    @Test
    func `every product dependency is package-qualified by evaluated identity`() throws {
        let plan = try Institute.Composition.BuildPlan(
            seeds: [],
            packages: [Self.package("swift-a-primitives", libraries: ["A One", "A Two"])]
        )
        let text = Institute.Composed.Root.render(plan, swift: "6.3.3")
        #expect(text.contains(".product(name: \"A One\", package: \"swift-a-primitives\"),"))
        #expect(text.contains(".product(name: \"A Two\", package: \"swift-a-primitives\"),"))
    }

    @Test
    func `a product-name collision across two identities renders unambiguously`() throws {
        let plan = try Institute.Composition.BuildPlan(
            seeds: [],
            packages: [
                Self.package("swift-a-primitives", libraries: ["Shared Name"]),
                Self.package("swift-b-primitives", libraries: ["Shared Name"]),
            ]
        )
        let text = Institute.Composed.Root.render(plan, swift: "6.3.3")
        #expect(text.contains(".product(name: \"Shared Name\", package: \"swift-a-primitives\"),"))
        #expect(text.contains(".product(name: \"Shared Name\", package: \"swift-b-primitives\"),"))
    }

    @Test
    func `zero library-product contribution is a typed non-success`() {
        #expect(throws: Institute.Composition.BuildPlan.Error.self) {
            _ = try Institute.Composition.BuildPlan(
                seeds: [],
                packages: [Self.package("swift-tool", libraries: [])]
            )
        }
    }

    @Test
    func `expected target count is computed from the exact plan`() throws {
        let plan = try Institute.Composition.BuildPlan(
            seeds: [],
            packages: [
                Self.package("swift-a-primitives", targets: 3),
                Self.package("swift-tool", libraries: [], targets: 5),
            ]
        )
        #expect(plan.expectedTargetCount == 3)
        #expect(plan.pathDependencyCount == 2)
        #expect(plan.libraryContributingCount == 1)
    }

    @Test
    func `a mixed-root plan renders paths that resolve`() throws {
        let base = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appending(path: UUID().uuidString)
        let rootOne = base.appending(path: "one/swift-primitives/swift-a-primitives")
        let rootTwo = base.appending(path: "two/swift-primitives/swift-b-primitives")
        let workspaceDirectory = base.appending(path: "workspaces")
        for directory in [rootOne, rootTwo, workspaceDirectory] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: base) }

        let workspace = Institute.Composition.Workspace.keyed(
            "mixed",
            under: try File.Directory(validating: workspaceDirectory.path),
            anchor: try File.Directory(validating: base.path)
        )
        let generated = Institute.Composed.Root.directory(in: workspace)

        let evaluation = Package.Manifest.Evaluation(
            name: .init("swift-a-primitives"),
            toolsVersion: .init(major: .init(6), minor: .init(3)),
            products: [],
            targets: []
        )
        let entries: [Institute.Composition.SourceMap.Entry] = [
            .init(
                repository: .init(
                    name: "swift-a-primitives",
                    url: "https://github.com/swift-primitives/swift-a-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                ),
                hierarchy: try Institute.Hierarchy.ID("one"),
                directory: try File.Directory(validating: rootOne.path),
                identity: "swift-a-primitives",
                evaluation: evaluation
            ),
            .init(
                repository: .init(
                    name: "swift-b-primitives",
                    url: "https://github.com/swift-primitives/swift-b-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                ),
                hierarchy: try Institute.Hierarchy.ID("two"),
                directory: try File.Directory(validating: rootTwo.path),
                identity: "swift-b-primitives",
                evaluation: .init(
                    name: .init("swift-b-primitives"),
                    toolsVersion: .init(major: .init(6), minor: .init(3)),
                    products: [],
                    targets: []
                )
            ),
        ]

        var packages = [Institute.Composition.BuildPlan.Package]()
        let root = generated.path
        for entry in entries {
            packages.append(
                .init(
                    identity: entry.identity,
                    reference: Institute.Composition.BuildPlan.relative(
                        from: root,
                        to: entry.directory.path
                    ),
                    libraryProducts: ["Library"],
                    buildableTargetCount: 1
                )
            )
        }

        for package in packages {
            let resolved = URL(fileURLWithPath: generated.path.description)
                .appending(path: package.reference)
                .standardizedFileURL
                .resolvingSymlinksInPath()
            #expect(
                FileManager.default.fileExists(atPath: resolved.path),
                "reference \(package.reference) does not resolve from \(generated)"
            )
        }
    }
}
