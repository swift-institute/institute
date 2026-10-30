import Lint
import Linter_Rules_Test_Support
import Institute_Model
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `upward layer edge Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`upward layer edge Tests` {
    static func observation(
        _ source: Swift::String,
        repository: Swift::String?,
        file: Swift::String = "/home/runner/work/checkout/Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`upward layer edge`(in: repository.flatMap(Institute.Repository.Coordinate.init))
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
    }

    static func manifest(_ urls: Swift::String...) -> Swift::String {
        "let package = Package(name: \"swift-owner\", dependencies: ["
            + urls.map { ".package(url: \"\($0)\", branch: \"main\")" }.joined(separator: ", ")
            + "])"
    }
}

extension Lint.Rule.`upward layer edge Tests`.Unit {
    @Test
    func `an atoms package depending on higher layers is flagged per edge`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest(
                "https://github.com/swift-atoms/swift-byte.git",
                "https://github.com/swift-molecules/swift-buffer.git",
                "https://github.com/swift-iso/swift-iso-9899.git",
                "https://github.com/swift-compositions/swift-json.git"
            ),
            repository: "swift-atoms/swift-owner"
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 3)
        #expect(observation.findings[0].message.hasPrefix("[upward layer edge] [PACKAGE-LAYER-DIRECTION]:"))
    }

    @Test
    func `a standards package may depend on atoms molecules and standards`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest(
                "https://github.com/swift-atoms/swift-byte.git",
                "https://github.com/swift-molecules/swift-buffer.git",
                "https://github.com/swift-standards/swift-uri-standard.git",
                "https://github.com/swift-ietf/swift-rfc-3986.git"
            ),
            repository: "swift-ietf/swift-rfc-9110"
        )
        #expect(observation.findings.isEmpty)
    }
}

extension Lint.Rule.`upward layer edge Tests`.`Edge Case` {
    @Test
    func `third-party organisations are not layered`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest(
                "https://github.com/swiftlang/swift-syntax.git",
                "https://github.com/apple/swift-argument-parser.git"
            ),
            repository: "swift-atoms/swift-owner"
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a manifest outside the layered organisations is inapplicable`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest("https://github.com/swift-compositions/swift-json.git"),
            repository: nil,
            file: "Package.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`upward layer edge Tests`.Integration {
    @Test
    func `a molecules package on standards is flagged`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest("https://github.com/swift-standards/swift-uri-standard.git"),
            repository: "swift-molecules/swift-owner",
            file: "/home/runner/work/swift-owner/swift-owner/Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("molecules package must not depend on the standards layer"))
    }
}

extension Lint.Rule.`upward layer edge Tests`.`Edge Case` {
    @Test
    func `the layer comes from the owner, not the checkout folder`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest("https://github.com/swift-compositions/swift-json.git"),
            repository: "swift-atoms/swift-owner",
            file: "/workspace/swift-compositions/swift-owner/Package.swift"
        )
        #expect(observation.findings.count == 1)
    }

    @Test
    func `a repository outside the Institute is inapplicable`() {
        let observation = Lint.Rule.`upward layer edge Tests`.observation(
            Lint.Rule.`upward layer edge Tests`.manifest("https://github.com/swift-compositions/swift-json.git"),
            repository: "apple/swift-owner",
            file: "/workspace/swift-atoms/swift-owner/Package.swift"
        )
        #expect(observation.applicability == .inapplicable)
    }
}
