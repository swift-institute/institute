import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension `Lint.Rule Tests` {
    @Suite
    struct `stratum target Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Lint.Rule Tests`.`stratum target Tests` {
    static func messages(_ source: Swift::String) -> [Swift::String] {
        Lint.Rule.`stratum target`.observe(Lint.Source.parsed(from: source, file: "Package.swift"), .warning)
            .findings.map(\.message)
    }
}

extension `Lint.Rule Tests`.`stratum target Tests`.Unit {
    @Test
    func `a stratum of the package, of another target and of a macro target is found with its action`() {
        let messages = `Lint.Rule Tests`.`stratum target Tests`.messages(
            """
            let package = Package(
                name: "swift-buffer",
                products: [
                    .library(name: "Buffer", targets: ["Buffer"]),
                    .library(name: "Buffer Primitive", targets: ["Buffer Primitive"]),
                ],
                targets: [
                    .target(name: "Buffer Primitive"),
                    .target(name: "Buffer", dependencies: ["Buffer Primitive", "Buffer Macro"]),
                    .target(name: "Buffer Ring"),
                    .target(name: "Buffer Ring Shared"),
                    .macro(name: "Buffer Macro", dependencies: ["Buffer Macro Core"]),
                    .target(name: "Buffer Macro Core"),
                ]
            )
            """
        )
        #expect(messages.count == 3)
        #expect(
            messages.first?.hasPrefix(
                "[stratum target]: a target named `<X> Primitive`, `<X> Core`, `<X> Shared`, `<X> Protocol` or "
                    + "`<X> Namespace`, where `<X>` claims the package, another of its targets or a public type it "
                    + "declares, is a stratum, and a stratum is never a target."
            ) == true
        )
        #expect(messages.contains { $0.contains("`Buffer Primitive` is the `Primitive` stratum of `Buffer`; fold it into `Buffer`") })
        #expect(messages.contains { $0.contains("`Buffer Ring Shared` is the `Shared` stratum of `Buffer Ring`; fold it into `Buffer Ring`") })
        #expect(
            messages.contains {
                $0.contains("`Buffer Macro Core` is the implementation of the macro target `Buffer Macro`; fold it into `Buffer Macro`")
            }
        )
    }

    @Test
    func `a part's own name that ends in a stratum word is not found`() {
        let messages = `Lint.Rule Tests`.`stratum target Tests`.messages(
            """
            let package = Package(
                name: "swift-sigma",
                targets: [.target(name: "Sigma"), .target(name: "Sigma Dublin Core"), .target(name: "Sigma Protocols")]
            )
            """
        )
        #expect(messages.isEmpty)
    }
}

extension `Lint.Rule Tests`.`stratum target Tests`.`Edge Case` {
    @Test
    func `a test target is never a stratum`() {
        let messages = `Lint.Rule Tests`.`stratum target Tests`.messages(
            """
            let package = Package(name: "swift-sigma", targets: [.target(name: "Sigma"), .testTarget(name: "Sigma Core")])
            """
        )
        #expect(messages.isEmpty)
    }
}

extension `Lint.Rule Tests`.`stratum target Tests`.Integration {
    @Test
    func `a stratum of a public type the package declares is found when the package is on disk`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": """
            let package = Package(
                name: "swift-sigma",
                targets: [.target(name: "Sigma"), .target(name: "Dublin Core"), .target(name: "Quill Core")]
            )
            """,
            "Sources/Sigma/Sigma.swift": "public enum Sigma {}\npublic typealias Dublin = Sigma",
            "Sources/Dublin Core/Value.swift": "struct Value {}",
            "Sources/Quill Core/Value.swift": "struct Value {}",
        ])
        let messages = Lint.Rule.`stratum target`.observe(fixture.parsed("Package.swift"), .warning).findings.map(\.message)
        #expect(messages.count == 1)
        #expect(messages.first?.contains("fold it into `Sigma`, which declares `Dublin`") == true)
    }
}
