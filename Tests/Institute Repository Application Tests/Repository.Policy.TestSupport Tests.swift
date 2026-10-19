import Byte
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Package_Manager
import Testing

@Suite
struct `Repository Policy Test Support Tests` {
    @Test
    func `allows supported and upstream Test Support dependencies`() {
        let evaluation = Package.Manifest.Evaluation(
            name: "Example",
            toolsVersion: .init(major: 6, minor: 3, patch: 0),
            products: [
                .init(name: "Example", kind: .library(.automatic), targets: ["Example"])
            ],
            targets: [
                .init(
                    name: "Example Test Support",
                    kind: .regular,
                    dependencies: [
                        .target(name: "Example"),
                        .product(
                            name: "Upstream Test Support",
                            package: "upstream"
                        ),
                    ]
                )
            ]
        )

        #expect(Institute.Repository.Policy.TestSupport.findings(in: evaluation).isEmpty)
    }

    @Test
    func `reports non-support cross-package dependency`() {
        let evaluation = Package.Manifest.Evaluation(
            name: "Example",
            toolsVersion: .init(major: 6, minor: 3, patch: 0),
            products: [
                .init(name: "Example", kind: .library(.automatic), targets: ["Example"])
            ],
            targets: [
                .init(
                    name: "Example Test Support",
                    kind: .regular,
                    dependencies: [
                        .product(name: "Foreign Runtime", package: "foreign")
                    ]
                )
            ]
        )

        #expect(
            Institute.Repository.Policy.TestSupport.findings(in: evaluation) == [
                .init(
                    target: "Example Test Support",
                    dependency: "Foreign Runtime"
                )
            ]
        )
    }
}
