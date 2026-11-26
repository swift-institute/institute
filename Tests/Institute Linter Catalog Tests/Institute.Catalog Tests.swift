import GitHub_Standard
import Institute_Linter_Rule_Naming
import Institute_Model
import Lint
import Linter_Institute_Rules
import Linter_Primitives_Rules
import Linter_Standards_Rules
import Testing

@testable import Institute_Linter_Catalog

extension Institute.Catalog {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Catalog.Test {
    /// One package of each Institute layer.
    static let repositories: [Swift::String] = [
        "swift-atoms/swift-byte",
        "swift-molecules/swift-lint",
        "swift-ietf/swift-rfc-3339",
        "swift-compositions/swift-json",
        "swift-institute/institute",
    ]

    /// The bundle `repository` is linted with, as the runner bakes it for that repository.
    static func bundle(for repository: Swift::String) -> [Lint.Rule.Configuration] {
        let slug = GitHub.Repository.Slug(repository)
        let coordinate = slug.flatMap(Institute.Repository.Coordinate.init)
        switch Institute.Organization.lintBundle(forRepository: slug) {
        case "primitives": return Lint.Rule.Bundle.primitives.located(in: coordinate)
        case "standards": return Lint.Rule.Bundle.standards.located(in: coordinate)
        default: return Lint.Rule.Bundle.institute.located(in: coordinate)
        }
    }

    /// The rules that state nothing here, because no control of theirs gives a finding: two read a package on disk
    /// and carry only a control with nothing to read, and `upward layer edge` has no layer above compositions.
    static let unstated: Swift::Set<Swift::String> = [
        "conflicting dependency url", "target import edge", "upward layer edge",
    ]

    /// The rules of swift-linter-rules that carry no control expecting a clean result, and so no example.
    static let unexampled: Swift::Set<Swift::String> = [
        "malformed suppression directive", "redundant refinement", "unchecked sendable categorization",
        "unchecked sendable noncopyable",
    ]

    static func entry(_ id: Swift::String, in repository: Swift::String = "swift-atoms/swift-byte") -> Institute.Catalog.Entry? {
        Institute.Catalog(bundle(for: repository)).entries.first { $0.id.underlying == id }
    }
}

extension Institute.Catalog.Test.Integration {
    @Test(arguments: Institute.Catalog.Test.repositories)
    func `every rule of the bundle of a package of each layer is in the catalog once`(repository: Swift::String) {
        let bundle = Institute.Catalog.Test.bundle(for: repository)
        let catalog = Institute.Catalog(bundle)
        let enabled = bundle.filter { $0.mode == .enabled }.map(\.rule.id.underlying)
        #expect(!enabled.isEmpty)
        #expect(catalog.entries.map(\.id.underlying) == enabled.sorted())
        #expect(Swift::Set(enabled).count == enabled.count)
    }

    @Test(arguments: Institute.Catalog.Test.repositories)
    func `every rule of the bundle is printed with its id at the head of its lines`(repository: Swift::String) {
        let bundle = Institute.Catalog.Test.bundle(for: repository)
        let lines = Institute.Catalog(bundle).lines()
        for configuration in bundle where configuration.mode == .enabled {
            let id = configuration.rule.id.underlying
            let severity = configuration.severity ?? configuration.rule.severity.default
            #expect(lines.count { $0.hasPrefix("\(id) (\(severity))") } == 1, "\(id)")
        }
    }

    @Test(arguments: Institute.Catalog.Test.repositories)
    func `a rule that applies has a statement and an example unless it is known to carry none`(
        repository: Swift::String
    ) {
        let catalog = Institute.Catalog(Institute.Catalog.Test.bundle(for: repository))
        for entry in catalog.entries where entry.applies {
            let id = entry.id.underlying
            if entry.statement?.isEmpty ?? true {
                #expect(Institute.Catalog.Test.unstated.contains(id), "\(id) has no statement")
            }
            if entry.examples.isEmpty {
                #expect(Institute.Catalog.Test.unexampled.contains(id), "\(id) has no example")
            }
            #expect(!entry.kinds.isEmpty, "\(id) names no kind of file")
            #expect(entry.written.isSubset(of: entry.kinds), "\(id)")
        }
    }

    @Test(arguments: Institute.Catalog.Test.repositories)
    func `a kind of file keeps the rules that give findings in it, its own first`(repository: Swift::String) {
        let catalog = Institute.Catalog(Institute.Catalog.Test.bundle(for: repository))
        for kind in Institute.Source.Kind.allCases {
            let kept = catalog.entries(for: kind)
            #expect(!kept.isEmpty)
            #expect(kept.count < catalog.entries.count)
            #expect(kept.allSatisfy { $0.kinds.contains(kind) })
            let heads = catalog.lines(for: kind).filter { !$0.hasPrefix(" ") && !$0.hasPrefix("==") && !$0.isEmpty }
            let own = kept.filter { $0.written.contains(kind) }.count
            #expect(heads.count == kept.count)
            #expect(catalog.summary(of: "bundle", for: kind).contains("\(kept.count) of \(catalog.entries.count) rules"))
            #expect(catalog.summary(of: "bundle", for: kind).contains("the \(own) written for one"))
        }
        let manifest = catalog.entries(for: .manifest).filter { $0.written.contains(.manifest) }.map(\.id.underlying)
        #expect(manifest.contains("path dependency"))
        #expect(!manifest.contains("variable named impl"))
        let test = catalog.entries(for: .test).map(\.id.underlying)
        #expect(test.contains("test file suffix"))
        #expect(test.contains("untyped throws"))
        #expect(!test.contains("fatal error outside tests"))
        #expect(!test.contains("path dependency"))
    }

    @Test
    func `a rule placed in a layer does not apply in a repository outside the layers`() {
        #expect(Institute.Catalog.Test.entry("upward layer edge", in: "swift-institute/institute")?.applies == false)
        #expect(Institute.Catalog.Test.entry("upward layer edge", in: "swift-atoms/swift-byte")?.applies == true)
        let lines = Institute.Catalog(Institute.Catalog.Test.bundle(for: "swift-institute/institute")).lines()
        let head = lines.firstIndex { $0.hasPrefix("upward layer edge (") }
        #expect(head.map { lines[$0 + 1].hasPrefix("  not in this repository") } == true)
    }
}

extension Institute.Catalog.Test.Unit {
    @Test
    func `the statement is the first sentence of the rule's own message, and the citation its place`() {
        let entry = Institute.Catalog.Test.entry("variable named impl")
        #expect(entry?.message?.hasPrefix("[variable named impl] [API-NAME-012]: do not bind") == true)
        #expect(entry?.citation == "[API-NAME-012]")
        #expect(entry?.statement == "do not bind a local as `impl` or `_impl` — it hides the type's identity.")
        #expect(entry?.severity == .error)
    }

    @Test
    func `the example is a control of the rule that it passes`() {
        let entry = Institute.Catalog.Test.entry("variable named impl")
        #expect(
            entry?.examples.first
                == .init(path: "Sources/Naming Core/ImplementationBinding.swift", source: "let implementation = make()")
        )
        let controls = Lint.Rule.`variable named impl`.controls.filter { $0.expectation == .clean }.map(\.source)
        #expect(entry?.examples.map(\.source) == controls)
    }

    @Test
    func `the lines of a rule are its head, its kinds, its statement and its example`() {
        let lines = Institute.Catalog([.enable(.`variable named impl`)]).lines()
        #expect(
            lines == [
                "variable named impl (warning) [API-NAME-012]",
                "  in: manifest, source, test",
                "  rule: do not bind a local as `impl` or `_impl` — it hides the type's identity.",
                "  passes, as Sources/Naming Core/ImplementationBinding.swift:",
                "      let implementation = make()",
                "",
            ]
        )
    }

    @Test(arguments: [
        ("Package.swift", Institute.Source.Kind.manifest),
        ("/workspace/swift-byte/Package.swift", .manifest),
        ("Package@swift-6.2.swift", .manifest),
        ("Sources/Byte/Byte.swift", .source),
        ("Controls/Value.swift", .source),
        ("Sources/Package/Package.Product.swift", .source),
        ("Tests/Byte Tests/Byte Tests.swift", .test),
        ("Tests/Support/Package.swift", .manifest),
    ])
    func `the kind of a file is read from its path`(path: Swift::String, kind: Institute.Source.Kind) {
        #expect(Institute.Catalog.kind(of: .init(path)) == kind)
    }

    @Test
    func `a file moved to another kind keeps its place under the other root`() {
        typealias Catalog = Institute.Catalog
        #expect(Catalog.relocating("Sources/Naming Core/Value.swift", to: .test) == "Tests/Naming Core/Value.swift")
        #expect(
            Catalog.relocating("Tests/Naming Tests/Value Tests.swift", to: .source) == "Sources/Naming Tests/Value Tests.swift"
        )
        #expect(Catalog.relocating("Controls/Value.swift", to: .test) == "Tests/Controls/Value.swift")
        #expect(Catalog.relocating("Sources/Naming Core/Value.swift", to: .manifest) == "Package.swift")
        #expect(Catalog.relocating("Sources/Naming Core/Value.swift", to: .source) == "Sources/Naming Core/Value.swift")
        #expect(Catalog.kind(of: Catalog.relocating("Package.swift", to: .source)) == .source)
        #expect(Catalog.kind(of: Catalog.relocating("Package.swift", to: .test)) == .test)
    }

    @Test
    func `a request names a bundle and at most one kind of file`() throws {
        typealias Request = Institute.Catalog.Request
        #expect(try Request(arguments: ["institute"]) == .init(bundle: "institute"))
        #expect(try Request(arguments: ["primitives", "test"]) == .init(bundle: "primitives", kind: .test))
        #expect(Request.usage == "usage: --catalog <bundle> [manifest | source | test]")
        #expect(throws: Institute.Error.self) { _ = try Request(arguments: []) }
        #expect(throws: Institute.Error.self) { _ = try Request(arguments: ["institute", "test", "more"]) }
        #expect {
            _ = try Request(arguments: ["institute", "header"])
        } throws: { error in
            "\(error)".hasPrefix("unknown kind of file 'header'; usage:")
        }
    }
}

extension Institute.Catalog.Test.`Edge Case` {
    @Test
    func `a control that passes only for where it is comes after one that passes for what it is`() {
        let entry = Institute.Catalog.Test.entry("diagnostic message format")
        #expect(entry?.examples.first?.source.contains("[try_optional] [API-ERR-001]: prefer typed throws") == true)
        #expect(entry?.examples.last?.path == "Sources/Controls/Helper.swift")
    }

    @Test
    func `a rule's plain control comes before its exemption when the rule lists it first`() {
        let entry = Institute.Catalog.Test.entry("path dependency")
        #expect(entry?.examples.first?.path == "Package.swift")
        #expect(entry?.examples.first?.source.contains("path:") == false)
        #expect(entry?.examples.dropFirst().contains { $0.path == "Tests/Package.swift" } == true)
    }

    @Test
    func `a disabled rule is not in the catalog`() {
        let catalog = Institute.Catalog([.disable(.`variable named impl`), .enable(.`nested tag`)])
        #expect(catalog.entries.map(\.id.underlying) == ["nested tag"])
    }

    @Test
    func `a rule with no control that gives a finding says so and is listed by its example's kind`() {
        let entry = Institute.Catalog.Test.entry("target import edge")
        #expect(entry?.statement == nil)
        #expect(entry?.kinds == [.manifest])
        let lines = Institute.Catalog(Institute.Catalog.Test.bundle(for: "swift-atoms/swift-byte")).lines()
        let head = lines.firstIndex { $0.hasPrefix("target import edge (") }
        #expect(head.map { lines[$0 + 2].hasPrefix("  rule: not stated") } == true)
    }

    @Test(arguments: [
        ("One thing. Another thing.", "One thing."),
        ("bare `throws` erases the error type", "bare `throws` erases the error type"),
        ("use a name (e.g. `walk.files()`). **Default**: refactor.", "use a name (e.g. `walk.files()`)."),
        ("write `a. B` (see X. Y) i.e. this. Then that.", "write `a. B` (see X. Y) i.e. this."),
        ("`UInt8.ascii` is gone. use `Byte`", "`UInt8.ascii` is gone. use `Byte`"),
    ])
    func `a sentence ends at a full stop outside code, parentheses and abbreviations`(
        text: Swift::String,
        sentence: Swift::String
    ) {
        #expect(Institute.Catalog.Entry.sentence(text) == sentence)
    }
}
