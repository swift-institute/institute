public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `compound suite name` = Lint.Rule(
        id: "compound suite name",
        default: .warning,
        controls: [
            .init(
                id: "compound suite name compound suite",
                source: "@Suite struct MemoryBufferTests {}",
                path: "Sources/Naming Core/CompoundSuite.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name domain test",
                source: "extension MemoryBuffer { @Suite struct Test {} }",
                path: "Sources/Naming Core/LeafSuite.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name canonical categories in domain test",
                source: "extension Foo { @Suite struct Test { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {}; @Suite(.serialized) struct Performance {} } }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name category in test extension",
                source: "extension Foo.Test { @Suite struct Unit {} }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name noncanonical category in domain test",
                source: "extension Foo { @Suite struct Test { @Suite struct EdgeCase {} } }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name category outside a domain test",
                source: "@Suite struct Unit {}\nextension Foo { @Suite struct Unit {} }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "compound suite name category reported once at a misplaced parent",
                source: "@Suite struct Test { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {} }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name domain template",
                source: "extension Foo { @Suite struct `Foo Tests` { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {} } }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name single-word fallback without a domain",
                source: "@Suite struct `Index Tests` { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {} }",
                path: "Tests/Naming Tests/Index Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name named test subdomain",
                source: "extension Parser { @Suite struct Parsing { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {} } }\n"
                    + "extension Parser.Parsing { @Suite struct Unit {} }",
                path: "Tests/Naming Tests/Parser Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name noncanonical child of a named subdomain",
                source: "extension Parser { @Suite struct Parsing { @Suite struct Helpers {} } }",
                path: "Tests/Naming Tests/Parser Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name concatenated tests suite in a domain",
                source: "extension Foo { @Suite struct FooTests {} }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name noncanonical child of a misplaced parent",
                source: "@Suite struct `Foo Bar Tests` { @Suite struct Helpers {} }",
                path: "Tests/Naming Tests/Foo Tests.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "compound suite name narrative suite",
                source: "@Suite struct `Memory Buffer Tests` {}",
                path: "Sources/Naming Core/NarrativeSuite.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingCompoundSuiteVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let namingCompoundSuiteMessage: Swift::String =
    "[compound suite name] [SWIFT-TEST-002]: a test suite is a subdomain of the source "
    + "type it covers, `extension Foo { @Suite struct <Subdomain> { ... } }`, holding "
    + "only the categories Unit, Edge Case, Integration and Performance. No compound "
    + "`FooTests` name; a category sits only inside its suite. Where the extension "
    + "cannot compile (a generic host), a top-level single-word suite such as "
    + "`@Suite struct \\`Index Tests\\``."

private func compoundSuiteHasSuiteAttribute(_ attributes: AttributeListSyntax) -> Swift::Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "Suite" { return true }
    }
    return false
}

private let compoundSuiteCategories: Swift::Set<Swift::String> = [
    "Unit", "Edge Case", "Integration", "Performance",
]

private func compoundSuiteIsConcatenated(_ name: TokenSyntax) -> Swift::Bool {
    let unescaped = Lint.Syntax.Identifier.unescaped(name.text)
    return unescaped.hasSuffix("Tests") && !unescaped.hasSuffix(" Tests")
}

private func compoundSuiteIsSingleWordFallback(_ name: TokenSyntax) -> Swift::Bool {
    let unescaped = Lint.Syntax.Identifier.unescaped(name.text)
    guard name.text.hasPrefix("`"), unescaped.hasSuffix(" Tests") else { return false }
    let word = unescaped.dropLast(" Tests".count)
    guard let first = word.first else { return false }
    return first.isUppercase && !word.contains(" ")
}

private func compoundSuiteIsLawful(_ node: Syntax, name: TokenSyntax) -> Swift::Bool {
    guard node.parent?.is(MemberBlockItemSyntax.self) == true,
        let container = node.parent?.parent?.parent?.parent
    else {
        return compoundSuiteIsSingleWordFallback(name)
    }
    let isCategory = compoundSuiteCategories.contains(Lint.Syntax.Identifier.unescaped(name.text))
    if !container.is(ExtensionDeclSyntax.self),
        let group = container.asProtocol((any DeclGroupSyntax).self),
        compoundSuiteHasSuiteAttribute(group.attributes)
    {
        return isCategory
    }
    if let extensionDecl = container.as(ExtensionDeclSyntax.self) {
        if isCategory { return extensionDecl.extendedType.is(MemberTypeSyntax.self) }
        return !compoundSuiteIsConcatenated(name)
    }
    guard
        container.is(StructDeclSyntax.self)
            || container.is(EnumDeclSyntax.self)
            || container.is(ClassDeclSyntax.self)
            || container.is(ActorDeclSyntax.self)
    else { return false }
    return !isCategory && !compoundSuiteIsConcatenated(name)
}

internal final class NamingCompoundSuiteVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func checkSuite(_ node: Syntax, attributes: AttributeListSyntax, name: TokenSyntax) {
        guard compoundSuiteHasSuiteAttribute(attributes) else { return }
        guard !compoundSuiteIsLawful(node, name: name) else { return }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "compound suite name",
                message: namingCompoundSuiteMessage
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(Syntax(node), attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(Syntax(node), attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(Syntax(node), attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(Syntax(node), attributes: node.attributes, name: node.name)
        return .visitChildren
    }
}
