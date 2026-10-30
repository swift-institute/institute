public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `ascii identifier` = Lint.Rule(
        id: "ascii identifier",
        default: .warning,
        controls: [
            .init(
                id: "ascii identifier accented type",
                source: "public struct Rechtspersoon\u{00E9} {}",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "ascii identifier english type",
                source: "public struct Entity {}",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "ascii identifier string content",
                source: "let greeting = \"caf\u{00E9}\"",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "ascii identifier test",
                source: "struct Caf\u{00E9} {}",
                path: "Tests/Naming Consumer Tests/Value.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = NamingASCIIIdentifierVisitor(
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
internal let namingASCIIIdentifierMessage: Swift::String =
    "[ascii identifier] [SOURCE-ENGLISH-IDENTIFIER]: declared names are English "
    + "and ASCII-only; non-ASCII text belongs in string literals, not identifiers."

internal final class NamingASCIIIdentifierVisitor: SyntaxVisitor {
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

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        guard case .identifier = token.tokenKind,
            !token.text.unicodeScalars.allSatisfy(\.isASCII),
            declares(token)
        else {
            return .visitChildren
        }
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "ascii identifier",
                message: namingASCIIIdentifierMessage
            )
        )
        return .visitChildren
    }

    private func declares(_ token: TokenSyntax) -> Swift::Bool {
        guard let parent = token.parent else { return false }
        return if let named = parent.asProtocol((any NamedDeclSyntax).self) {
            named.name.id == token.id
        } else if let pattern = parent.as(IdentifierPatternSyntax.self) {
            pattern.identifier.id == token.id
        } else if let parameter = parent.as(FunctionParameterSyntax.self) {
            parameter.firstName.id == token.id || parameter.secondName?.id == token.id
        } else if let element = parent.as(EnumCaseElementSyntax.self) {
            element.name.id == token.id
        } else {
            false
        }
    }
}
