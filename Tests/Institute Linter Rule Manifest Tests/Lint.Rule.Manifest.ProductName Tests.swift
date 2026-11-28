import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension `Lint.Rule Tests` {
    @Suite
    struct `product name Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `Lint.Rule Tests`.`product name Tests` {
    static func observation(_ source: Swift::String) -> Lint.Rule.Observation {
        Lint.Rule.`product name`.observe(Lint.Source.parsed(from: source, file: "Package.swift"), .warning)
    }
}

extension `Lint.Rule Tests`.`product name Tests`.Unit {
    @Test
    func `every product other than the primary is the primary name and a role`() {
        let observation = `Lint.Rule Tests`.`product name Tests`.observation(
            """
            let package = Package(
                name: "swift-motion",
                products: [
                    .library(name: "Motion", targets: ["Motion"]),
                    .library(name: "Motion Encoding", targets: ["Motion Encoding"]),
                    .library(name: "Encoding Motion", targets: ["Encoding Motion"]),
                    .library(name: "Motion", targets: ["Motion"]),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
        #expect(
            observation.findings.first?.message
                == "[product name] [I4]: a library product that is not the primary product is named `<Primary> <Role>`. "
                + "`Encoding Motion` does not begin with `Motion `; name it `Motion` and its role in words."
        )
    }
}

extension `Lint.Rule Tests`.`product name Tests`.`Edge Case` {
    @Test
    func `a package with no primary product is inapplicable`() {
        let observation = `Lint.Rule Tests`.`product name Tests`.observation(
            """
            let package = Package(
                name: "swift-motion",
                products: [.library(name: "Encoding", targets: ["Encoding"])]
            )
            """
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `the primary name followed by nothing but a space is no role`() {
        let observation = `Lint.Rule Tests`.`product name Tests`.observation(
            """
            let package = Package(
                name: "swift-motion",
                products: [.library(name: "Motion", targets: ["Motion"]), .library(name: "Motion ", targets: ["M"])]
            )
            """
        )
        #expect(observation.findings.count == 1)
    }
}
