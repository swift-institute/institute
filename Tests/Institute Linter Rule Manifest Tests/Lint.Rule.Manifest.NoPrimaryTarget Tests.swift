import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension `Lint.Rule Tests` {
    @Suite
    struct `no primary target Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `Lint.Rule Tests`.`no primary target Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Package.swift") -> [Swift::String] {
        Lint.Rule.`no primary target`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings.map(\.message)
    }
}

extension `Lint.Rule Tests`.`no primary target Tests`.Unit {
    @Test
    func `a product named for the package that holds a target of another name is found`() {
        let messages = `Lint.Rule Tests`.`no primary target Tests`.findings(
            """
            let package = Package(
                name: "swift-kernel",
                products: [.library(name: "Kernel", targets: ["Kernel Primitives"])],
                targets: [.target(name: "Kernel Primitives")]
            )
            """
        )
        #expect(messages.count == 1)
        #expect(
            messages.first?.hasPrefix(
                "[no primary target] [I4]: a library's root package has a regular target whose name claims the concept "
                    + "the package's name claims, and a library product of that name. `swift-kernel` has no regular target"
            ) == true
        )
    }

    @Test
    func `a primary target that no product exposes is found`() {
        let messages = `Lint.Rule Tests`.`no primary target Tests`.findings(
            """
            let package = Package(
                name: "swift-kernel",
                products: [.library(name: "Kernel File", targets: ["Kernel File"])],
                targets: [.target(name: "Kernel"), .target(name: "Kernel File", dependencies: ["Kernel"])]
            )
            """
        )
        #expect(messages.count == 1)
        #expect(messages.first?.contains("No library product exposes `Kernel`") == true)
    }

    @Test
    func `a package whose only product is a macro is found`() {
        let messages = `Lint.Rule Tests`.`no primary target Tests`.findings(
            """
            let package = Package(
                name: "swift-witness",
                products: [.library(name: "Witness Macro", targets: ["Witness Macro"])],
                targets: [
                    .target(name: "Witness Macro", dependencies: ["Witness Macro Plugin"]),
                    .macro(name: "Witness Macro Plugin"),
                ]
            )
            """
        )
        #expect(messages.count == 1)
    }

    @Test
    func `a primary product that holds the primary target is clean, whatever separates the words`() {
        let messages = `Lint.Rule Tests`.`no primary target Tests`.findings(
            """
            let package = Package(
                name: "swift-file-system",
                products: [.library(name: "File System", targets: ["File System"])],
                targets: [.target(name: "File System")]
            )
            """
        )
        #expect(messages.isEmpty)
    }
}

extension `Lint.Rule Tests`.`no primary target Tests`.`Edge Case` {
    @Test
    func `a package with no library product and a nested package are inapplicable`() {
        let executable = Lint.Rule.`no primary target`.observe(
            Lint.Source.parsed(
                from: "let package = Package(name: \"swift-tool\", products: [.executable(name: \"tool\", targets: [\"Tool\"])])",
                file: "Package.swift"
            ),
            .warning
        )
        let nested = Lint.Rule.`no primary target`.observe(
            Lint.Source.parsed(
                from: "let package = Package(name: \"fixture\", products: [.library(name: \"A\", targets: [\"A\"])])",
                file: "Tests/Fixtures/Package.swift"
            ),
            .warning
        )
        #expect(executable.applicability == .inapplicable)
        #expect(nested.applicability == .inapplicable)
    }

    @Test
    func `a primary product that holds other targets but not the primary target is found`() {
        let messages = `Lint.Rule Tests`.`no primary target Tests`.findings(
            """
            let package = Package(
                name: "swift-kernel",
                products: [.library(name: "Kernel", targets: ["Kernel Core"])],
                targets: [.target(name: "Kernel"), .target(name: "Kernel Core")]
            )
            """
        )
        #expect(messages.first?.contains("The product `Kernel` does not hold the target `Kernel`.") == true)
    }
}
