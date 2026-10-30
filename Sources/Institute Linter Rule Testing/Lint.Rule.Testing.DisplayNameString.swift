public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `test display name string` = Lint.Rule(
        id: "test display name string",
        default: .warning,
        controls: [
            .init(
                id: "test display name string descriptive literal",
                source: "@Test(\"creates value\") func fixture() {}",
                path: "Tests/Testing Tests/Value Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "test display name string declaration name",
                source: "@Test func `creates value`() {}",
                path: "Tests/Testing Tests/Value Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "test display name string operator boundary",
                source: "@Test(\"<=>\") func comparison() {}",
                path: "Tests/Testing Tests/Value Tests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = TestingDisplayNameStringVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            guard let contents = testingDisplayNameStringFixed(source) else { return .unchanged }
            return .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let testingDisplayNameStringMessage: Swift::String =
    "[test display name string] [SWIFT-TEST-006]: `@Test`/`@Suite` carries a "
    + "string display name whose content could be spelled as a backticked raw "
    + "identifier. The string duplicates naming into data the compiler cannot "
    + "check. **Rename required; autofix refused**: changing the declaration "
    + "token changes identity and requires a reviewed or compiler-aware rename "
    + "that accounts for references, filters, `#function`, and snapshot keys. "
    + "The planned result renames the declaration to the backticked descriptive "
    + "form and drops the string, keeping every trailing trait — "
    + "`@Test(\"init creates empty buffer\") func x()` becomes "
    + "`@Test func \\`init creates empty buffer\\`()`; "
    + "`@Suite(\"Parsing\", .serialized)` becomes "
    + "`@Suite(.serialized) struct \\`Parsing\\``. "
    + "**Exempt**: a display string that cannot be a raw identifier — it "
    + "contains a backtick, a backslash, whitespace other than a plain space, "
    + "is empty, or is all operator characters."

@usableFromInline
internal let testingDisplayNameDuplicateMessage: Swift::String =
    "[test display name string] [SWIFT-TEST-006]: `@Test`/`@Suite` string "
    + "display name duplicates the declaration's own backticked raw-identifier "
    + "name. This is a COMPILE ERROR on Swift 6.3/6.4 — the explicit display "
    + "name repeats the implicit one. **Canonical fix**: delete only the string "
    + "argument and keep the backticked declaration token, attribute "
    + "qualification, every trailing trait, and trivia."

private let displayNameOperatorCharacters: Set<Character> = [
    "/", "=", "-", "+", "!", "*", "%", "<", ">", "&", "|", "^", "~", ".", "?",
]

internal func testingDisplayNameAttribute(_ attributes: AttributeListSyntax) -> AttributeSyntax? {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        let name = attr.attributeName.trimmedDescription
        for candidate in ["Test", "Suite"]
        where name == candidate || name.hasSuffix(".\(candidate)") {
            return attr
        }
    }
    return nil
}

internal func testingDisplayNameLiteral(_ attribute: AttributeSyntax) -> StringLiteralExprSyntax? {
    guard case .argumentList(let arguments) = attribute.arguments else { return nil }
    for argument in arguments {
        guard argument.label == nil else { continue }
        if let literal = argument.expression.as(StringLiteralExprSyntax.self) { return literal }
    }
    return nil
}

internal func testingDisplayNameContent(_ literal: StringLiteralExprSyntax) -> Swift::String? {
    var content = ""
    for segment in literal.segments {
        guard case .stringSegment(let plain) = segment else { return nil }
        content += plain.content.text
    }
    return content
}

internal func testingDisplayNameDuplicatesDeclaration(
    name: TokenSyntax,
    content: Swift::String
) -> Swift::Bool {
    let spelled = name.trimmedDescription
    return spelled.hasPrefix("`") && spelled.hasSuffix("`")
        && Swift::String(spelled.dropFirst().dropLast()) == content
}

internal func displayNameCanBeRawIdentifier(_ text: Swift::String) -> Swift::Bool {
    guard !text.isEmpty else { return false }
    for character in text {
        if character == "`" || character == "\\" { return false }
        if character.isWhitespace && character != " " { return false }
    }
    guard text.contains(where: { $0 != " " }) else { return false }
    guard text.contains(where: { !displayNameOperatorCharacters.contains($0) }) else {
        return false
    }
    return true
}

internal final class TestingDisplayNameStringVisitor: SyntaxVisitor {
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

    private func check(name: TokenSyntax, attributes: AttributeListSyntax) {
        guard let attribute = testingDisplayNameAttribute(attributes) else { return }
        guard let literal = testingDisplayNameLiteral(attribute) else { return }
        guard let content = testingDisplayNameContent(literal) else { return }
        guard displayNameCanBeRawIdentifier(content) else { return }

        let isDuplicate = testingDisplayNameDuplicatesDeclaration(name: name, content: content)

        let location = converter.location(for: literal.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "test display name string",
                message: isDuplicate
                    ? testingDisplayNameDuplicateMessage : testingDisplayNameStringMessage
            )
        )
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes)
        return .visitChildren
    }
}
