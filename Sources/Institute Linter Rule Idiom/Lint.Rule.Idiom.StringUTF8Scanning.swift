public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `string utf8 scanning` = Lint.Rule(
        id: "string utf8 scanning",
        default: .warning,
        controls: [
            .init(
                id: "string utf8 scanning unicode scalars",
                source: "func scan(content: String) { _ = content.unicodeScalars.firstIndex(of: \"x\") }",
                path: "Sources/String Core/UnicodeScalars.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "string utf8 scanning utf8",
                source: "func scan(content: String) { _ = content.utf8.firstIndex(of: 0x78) }",
                path: "Sources/String Core/UTF8.swift",
                expectation: .clean
            ),
            .init(
                id: "string utf8 scanning Foundation",
                source: "import Foundation\nfunc scan(content: String) { _ = content.unicodeScalars.firstIndex(of: \"x\") }",
                path: "Sources/String Foundation Integration/UnicodeScalars.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !idiomFileImportsFoundation(source.tree) else {
                return []
            }
            let visitor = IdiomStringUTF8ScanningVisitor(
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
internal let idiomStringUTF8ScanningMessage: Swift::String =
    "[string utf8 scanning] [IMPL-089]: `.unicodeScalars` access is "
    + "the wrong code-unit view for Foundation-free string scanning. "
    + "Use `.utf8` — byte-literal matching is O(n), no Unicode table "
    + "dependency, and the correct semantics for newline discovery, "
    + "substring search, percent decoding, path component splitting. "
    + "**Accept-as-warning** disposition (rule fires legitimately, leave the "
    + "warning): a specification whose algorithm is DEFINED over Unicode "
    + "scalars / code points rather than bytes — e.g. RFC 3492 Punycode, "
    + "whose encoding is specified in code points, or a Unicode "
    + "normalization / case-mapping algorithm. `.unicodeScalars` is the "
    + "correct view there; the warning is the review signal, not a defect. "
    + "Suppress a confirmed non-`String` receiver, or a spec-mandated "
    + "scalar algorithm you have reviewed, with a "
    + "`// swift-linter:disable:next string utf8 scanning` and `// REASON:` "
    + "continuation naming the specification section."

private let idiomFoundationModuleFamily: Swift::Set<Swift::String> = [
    "Foundation",
    "FoundationEssentials",
    "FoundationNetworking",
    "FoundationXML",
]

internal func idiomFileImportsFoundation(_ tree: SourceFileSyntax) -> Swift::Bool {
    for statement in tree.statements {
        guard let importDecl = statement.item.as(ImportDeclSyntax.self) else { continue }
        let firstComponent =
            importDecl.path.trimmedDescription.split(separator: ".").first.map(Swift::String.init)
            ?? importDecl.path.trimmedDescription
        if idiomFoundationModuleFamily.contains(firstComponent) {
            return true
        }
    }
    return false
}

internal final class IdiomStringUTF8ScanningVisitor: SyntaxVisitor {
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

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.declName.baseName.text == "unicodeScalars" else { return .visitChildren }
        let location = converter.location(
            for: node.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "string utf8 scanning",
                message: idiomStringUTF8ScanningMessage
            )
        )
        return .visitChildren
    }
}
