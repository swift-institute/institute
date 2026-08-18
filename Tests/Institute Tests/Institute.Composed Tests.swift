import Standard_Library_Extensions
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

extension Institute.Composed {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Composed.Test {
    static func manifest(
        reference: Swift.String,
        package: Swift.String,
        libraryProducts: [Swift.String],
        buildableTargetCount: Swift.Int = 1
    ) -> Institute.Composed.Manifest {
        .init(
            reference: reference,
            package: package,
            identity: package,
            libraryProducts: libraryProducts,
            buildableTargetCount: buildableTargetCount
        )
    }
}

extension Institute.Composed.Test.Unit {
    @Test
    func
        `The rendered manifest declares one path dependency and one product dependency per contributing repository`()
    {
        let manifests = [
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-two",
                package: "swift-example-two",
                libraryProducts: ["Example Two"],
                buildableTargetCount: 2
            ),
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One", "Example One Testing"],
                buildableTargetCount: 3
            ),
        ]

        let text = Institute.Composed.Root.render(manifests, swift: "6.3.3")

        #expect(text.hasPrefix("// swift-tools-version: 6.3.3\n"))
        #expect(text.contains(".package(path: \"../swift-primitives/swift-example-one\"),"))
        #expect(text.contains(".package(path: \"../swift-primitives/swift-example-two\"),"))
        #expect(
            text.contains(
                ".product(name: \"Example One\", package: \"swift-example-one\"),"
            )
        )
        #expect(
            text.contains(
                ".product(name: \"Example One Testing\", package: \"swift-example-one\"),"
            )
        )
        #expect(
            text.contains(
                ".product(name: \"Example Two\", package: \"swift-example-two\"),"
            )
        )

        // Sorted by reference regardless of input order, so the render is
        // deterministic run over run on the same selection.
        let oneIndex = text.range(of: "swift-example-one")!.lowerBound
        let twoIndex = text.range(of: "swift-example-two")!.lowerBound
        #expect(oneIndex < twoIndex)
    }

    @Test
    func `Rendering the same manifests twice produces byte-identical text`() {
        let manifests = [
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"]
            )
        ]

        let first = Institute.Composed.Root.render(manifests, swift: "6.3.3")
        let second = Institute.Composed.Root.render(manifests, swift: "6.3.3")

        #expect(first == second)
    }

    @Test
    func `Expected target count sums only the repositories contributing a library product`() {
        let manifests = [
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"],
                buildableTargetCount: 3
            ),
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-two",
                package: "swift-example-two",
                libraryProducts: ["Example Two"],
                buildableTargetCount: 2
            ),
        ]

        #expect(Institute.Composed.Root.expectedTargetCount(in: manifests) == 5)
    }
}

extension Institute.Composed.Test.`Edge Case` {
    @Test
    func
        `A repository with no library product is excluded from the composed root and its target count`()
        throws
    {
        let manifests = [
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"],
                buildableTargetCount: 3
            ),
            // An executable-only repository: no library product, so it has
            // no way into the composed graph through a product dependency.
            Institute.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-tool",
                package: "swift-example-tool",
                libraryProducts: [],
                buildableTargetCount: 1
            ),
        ]

        // Legacy manifest-based adapter: the historical contract keeps
        // the library-less repository out of the render entirely.
        let text = Institute.Composed.Root.render(manifests, swift: "6.3.3")
        #expect(!text.contains("swift-example-tool"))
        #expect(Institute.Composed.Root.expectedTargetCount(in: manifests) == 3)

        // Validated plan path: the library-less package stays a path
        // dependency — visible to resolution — and is excluded from
        // synthetic target dependencies with a typed reason code.
        let plan = try Institute.Composition.BuildPlan(
            seeds: [],
            packages: manifests.map { manifest in
                .init(
                    identity: manifest.identity,
                    reference: manifest.reference,
                    libraryProducts: manifest.libraryProducts,
                    buildableTargetCount: manifest.buildableTargetCount
                )
            }
        )
        let planText = Institute.Composed.Root.render(plan, swift: "6.3.3")
        #expect(planText.contains(".package(path: \"../swift-primitives/swift-example-tool\"),"))
        #expect(!planText.contains("package: \"swift-example-tool\""))
        #expect(plan.pathDependencyCount == 2)
        #expect(plan.libraryContributingCount == 1)
        #expect(plan.expectedTargetCount == 3)
        #expect(plan.exclusions.count == 1)
        #expect(plan.exclusions.first?.reason == .noLibraryProduct)
    }

    @Test
    func
        `An empty selection renders a composed root with no dependencies and an expected count of zero`()
    {
        let text = Institute.Composed.Root.render([], swift: "6.3.3")

        #expect(text.contains("dependencies: [\n    ],"))
        #expect(Institute.Composed.Root.expectedTargetCount(in: []) == 0)
    }
}
