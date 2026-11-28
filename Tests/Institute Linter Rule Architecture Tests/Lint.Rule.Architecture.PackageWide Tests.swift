import Institute_Model
import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Architecture

extension `Lint.Rule Tests` {
    @Suite
    struct `empty target Tests` {
        @Suite struct Unit {}
    }

    @Suite
    struct `duplicate type path Tests` {
        @Suite struct Unit {}
    }

    @Suite
    struct `claimed path owner Tests` {
        @Suite struct Unit {}
    }

    @Suite
    struct `top level type owner Tests` {
        @Suite struct Unit {}
    }
}

extension `Lint.Rule Tests`.`empty target Tests`.Unit {
    @Test
    func `a target is empty only when every one of its files declares nothing`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": """
            let package = Package(
                name: "swift-owner",
                targets: [
                    .target(name: "Owner"),
                    .target(name: "Owner Glob", dependencies: ["Owner"]),
                    .target(name: "Owner Test Support", dependencies: ["Owner"], path: "Tests/Support"),
                    .testTarget(name: "Owner Tests", dependencies: ["Owner"]),
                ]
            )
            """,
            "Sources/Owner/Owner.swift": "public enum Owner {}",
            "Sources/Owner/exports.swift": "@_exported public import Glob",
            "Sources/Owner/Owner.Value.swift": "extension Owner {\n    public struct Value {}\n}",
            "Sources/Owner Glob/exports.swift": "@_exported public import Owner",
            "Sources/Owner Glob/Owner.Glob.swift": "#if Glob\nextension Owner {\n    public enum Glob {}\n}\n#endif",
            "Tests/Support/exports.swift": "@_exported public import Owner",
            "Tests/Owner Tests/exports.swift": "@_exported public import Owner",
        ])
        let rule = Lint.Rule.`empty target`
        #expect(rule.observe(fixture.parsed("Sources/Owner/Owner.Value.swift"), .warning).findings.isEmpty)
        #expect(rule.observe(fixture.parsed("Sources/Owner/exports.swift"), .warning).findings.isEmpty)
        #expect(rule.observe(fixture.parsed("Sources/Owner Glob/Owner.Glob.swift"), .warning).findings.count == 1)
        #expect(rule.observe(fixture.parsed("Sources/Owner Glob/exports.swift"), .warning).findings.isEmpty)
        let support = rule.observe(fixture.parsed("Tests/Support/exports.swift"), .warning)
        #expect(support.findings.first?.message.contains("`Owner Test Support` declares nothing") == true)
        #expect(rule.observe(fixture.parsed("Tests/Owner Tests/exports.swift"), .warning).applicability == .inapplicable)
    }

    @Test
    func `a target that declares only the namespace its package's name claims is no finding`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": """
            let package = Package(
                name: "swift-ietf",
                targets: [
                    .target(name: "IETF"),
                    .target(name: "IETF Glob", dependencies: ["IETF"]),
                    .target(name: "IETF Other", dependencies: ["IETF"]),
                ]
            )
            """,
            "Sources/IETF/IETF.swift": "public enum IETF {}",
            "Sources/IETF/exports.swift": "@_exported public import Glob",
            "Sources/IETF Glob/IETF.Glob.swift": "extension IETF {\n    public enum Glob {}\n}",
            "Sources/IETF Other/IETF.swift": "public enum IETF {}\npublic enum Other {}",
        ])
        let rule = Lint.Rule.`empty target`
        #expect(rule.observe(fixture.parsed("Sources/IETF/IETF.swift"), .warning).findings.isEmpty)
        #expect(rule.observe(fixture.parsed("Sources/IETF Glob/IETF.Glob.swift"), .warning).findings.count == 1)
        #expect(rule.observe(fixture.parsed("Sources/IETF Other/IETF.swift"), .warning).findings.count == 1)
    }

    @Test
    func `a type, a typealias, a function or a conformance is a declaration`() {
        for source in [
            "public typealias Glob = Int",
            "public func glob() {}",
            "extension Owner: Sendable {}",
            "public enum Glob { case star }",
            "public enum Glob: Error {}",
        ] {
            let observation = Lint.Rule.`empty target`.observe(
                Lint.Source.parsed(from: source, file: "Sources/Owner Glob/Glob.swift"),
                .warning
            )
            #expect(observation.findings.isEmpty, "\(source)")
        }
    }
}

extension `Lint.Rule Tests`.`duplicate type path Tests`.Unit {
    @Test
    func `a path declared in two targets is found once, on the later file`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": """
            let package = Package(
                name: "swift-owner",
                targets: [.target(name: "Owner"), .target(name: "Owner Glob", dependencies: ["Owner"])]
            )
            """,
            "Sources/Owner/Owner.swift": "public enum Owner {}\nextension Owner {\n    public struct Error: Swift.Error {}\n}",
            "Sources/Owner Glob/Owner.Error.swift": "extension Owner {\n    public struct Error: Swift.Error {}\n}",
        ])
        let rule = Lint.Rule.`duplicate type path`
        #expect(rule.observe(fixture.parsed("Sources/Owner Glob/Owner.Error.swift"), .warning).findings.isEmpty)
        let later = rule.observe(fixture.parsed("Sources/Owner/Owner.swift"), .warning).findings
        #expect(later.count == 1)
        #expect(later.first?.message.contains("`Owner.Error` is declared again here") == true)
    }

    @Test
    func `a public extension makes its members public, and generic arguments and backticks are not part of the path`() {
        let observation = Lint.Rule.`duplicate type path`.observe(
            Lint.Source.parsed(
                from: "public extension Box<Int> {\n    struct Error {}\n}\nextension `Box` {\n    public struct Error {}\n}",
                file: "Sources/Owner/Box.swift"
            ),
            .warning
        )
        #expect(observation.findings.count == 1)
    }
}

extension `Lint.Rule Tests`.`claimed path owner Tests`.Unit {
    static let atoms = Institute.Repository.Coordinate(organization: .`swift-atoms`, name: "swift-owner")

    @Test
    func `controls hold in each layer`() {
        let repositories: [Institute.Repository.Coordinate] = [
            Self.atoms,
            .init(organization: .`swift-molecules`, name: "swift-buffer-ring"),
            .init(organization: .`swift-ietf`, name: "swift-ietf-rfc-3986"),
            .init(organization: .`swift-iso`, name: "swift-iso-9945"),
            .init(organization: .`swift-standards`, name: "swift-github-standard"),
            .init(organization: .`swift-compositions`, name: "swift-zebra"),
            .init(organization: .`swift-institute`, name: "institute"),
        ]
        for repository in repositories {
            for outcome in Lint.Rule.`claimed path owner`(in: repository).outcomes() {
                #expect(outcome.holds, "\(repository.name): \(outcome)")
            }
        }
    }

    @Test
    func `a package is found once when no file declares the path its name claims`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": "let package = Package(name: \"swift-owners\", targets: [.target(name: \"Owners\")])",
            "Sources/Owners/A.swift": "public enum Owner {}",
            "Sources/Owners/B.swift": "extension Owner {\n    public struct Value {}\n}",
        ])
        let rule = Lint.Rule.`claimed path owner`(
            in: .init(organization: .`swift-atoms`, name: "swift-owners")
        )
        let first = rule.observe(fixture.parsed("Sources/Owners/A.swift"), .warning).findings
        #expect(first.count == 1)
        #expect(
            first.first?.message.hasPrefix(
                "[claimed path owner] [ARCH-ONE-TYPE]: a package owns at least one declaration, a type, a typealias or "
                    + "a macro, at the path its name claims, read whole from the first component."
            ) == true
        )
        #expect(rule.observe(fixture.parsed("Sources/Owners/B.swift"), .warning).findings.isEmpty)
    }

    @Test
    func `the claimed path is read whole from its first component`() {
        let cases: [(Institute.Repository.Coordinate, Swift::String, Swift::Bool)] = [
            (.init(organization: .`swift-molecules`, name: "swift-buffer-ring"), "extension Buffer {\n    public struct Ring {}\n}", true),
            (.init(organization: .`swift-ietf`, name: "swift-ietf-rfc-3986"), "extension IETF.RFC {\n    public enum `3986` {}\n}", true),
            (.init(organization: .`swift-iso`, name: "swift-iso-9945"), "extension ISO {\n    public enum `9945` {}\n}", true),
            (.init(organization: .`swift-ietf`, name: "swift-rfc-3986"), "extension IETF.RFC {\n    public enum `3986` {}\n}", false),
            (.init(organization: .`swift-standards`, name: "swift-github-standard"), "public enum GitHub {}", false),
            (.init(organization: .`swift-compositions`, name: "swift-uri"), "extension URI {\n    public struct Parser {}\n}", false),
            (.init(organization: .`swift-atoms`, name: "swift-processes"), "public enum Process {}", false),
        ]
        for (repository, source, claims) in cases {
            let observation = Lint.Rule.`claimed path owner`(in: repository).observe(
                Lint.Source.parsed(from: source, file: "/workspace/\(repository.name)/Sources/Owner/Owner.swift"),
                .warning
            )
            #expect(observation.findings.isEmpty == claims, "\(repository.name): \(source)")
        }
    }
}

extension `Lint.Rule Tests`.`top level type owner Tests`.Unit {
    @Test
    func `an authority's namespace is owned only by the package named for it, and compositions are judged`() {
        let authority = Institute.Repository.Coordinate(organization: .`swift-ietf`, name: "swift-ietf")
        let standard = Institute.Repository.Coordinate(organization: .`swift-standards`, name: "swift-github-standard")
        let composition = Institute.Repository.Coordinate(organization: .`swift-compositions`, name: "swift-json")
        let file = "/workspace/repo/Sources/Owner/Owner.swift"
        #expect(
            Lint.Rule.`top level type owner`(in: authority)
                .observe(Lint.Source.parsed(from: "public enum IETF {}", file: file), .warning).findings.isEmpty
        )
        #expect(
            Lint.Rule.`top level type owner`(in: standard)
                .observe(Lint.Source.parsed(from: "public enum GitHub {}", file: file), .warning).findings.count == 1
        )
        #expect(
            Lint.Rule.`top level type owner`(in: composition)
                .observe(Lint.Source.parsed(from: "public enum Zebra {}", file: file), .warning).findings.count == 1
        )
        for repository in [authority, standard] {
            for outcome in Lint.Rule.`top level type owner`(in: repository).outcomes() {
                #expect(outcome.holds, "\(repository.name): \(outcome)")
            }
        }
    }
}
