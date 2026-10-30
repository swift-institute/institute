public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `dead case per platform` = Lint.Rule(
        id: "dead case per platform",
        default: .warning,
        controls: [
            .init(
                id: "dead case per platform public platform cases",
                source: "public enum Encoding { case posix; case windows }",
                path: "Sources/Platform Core/PlatformEncoding.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "dead case per platform string vocabulary",
                source: "public enum Platform: String { case macOS = \"macos\"; case linux = \"linux\" }",
                path: "Sources/Platform Core/Platform.swift",
                expectation: .clean
            ),
            .init(
                id: "dead case per platform integer raw value",
                source: "public enum Encoding: UInt8 { case posix; case windows }",
                path: "Sources/Platform Core/PlatformEncoding.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "dead case per platform string conformance not first",
                source: "public enum Encoding: Sendable, CustomStringConvertible { case posix; case windows }",
                path: "Sources/Platform Core/PlatformEncoding.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "dead case per platform domain alternatives",
                source: "public enum URLScheme { case http; case https }",
                path: "Sources/Platform Core/DomainAlternatives.swift",
                expectation: .clean
            ),
            .init(
                id: "dead case per platform internal boundary",
                source: "internal enum Encoding { case posix; case windows }",
                path: "Sources/Platform Core/InternalEncoding.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformDeadCasePerPlatformVisitor(
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
internal let platformDeadCasePerPlatformMessage: Swift::String =
    "[dead case per platform] [PATTERN-056]: public enum cases "
    + "enumerate platforms (POSIX / Windows or UTF8 / UTF16). Consumer "
    + "`switch` statements get N-1 dead branches per platform. Replace "
    + "with the ecosystem's existing platform-conditional typealias "
    + "(`Path.Char`, `String.Char`) for storage; add a local `Encoding` "
    + "typealias for decoder calls."

internal let platformDeadCasePerPlatformPlatformPairs: [Swift::Set<Swift::String>] = [
    ["posix", "windows"],
    ["utf8", "utf16"],
    ["linux", "darwin"],
    ["linux", "darwin", "windows"],
    ["linux", "darwin", "windows", "freebsd"],
    ["macos", "linux"],
    ["macos", "windows"],
]

internal func platformDeadCasePerPlatformMatchesPlatformPair(_ cases: [Swift::String]) -> Swift::Bool {
    let lower = Swift::Set(cases.map { $0.lowercased() })
    for pair in platformDeadCasePerPlatformPlatformPairs {
        if pair.isSubset(of: lower) {
            return true
        }
    }
    return false
}

internal func platformDeadCasePerPlatformIsStringVocabulary(_ node: EnumDeclSyntax) -> Swift::Bool {
    guard let rawType = node.inheritanceClause?.inheritedTypes.first?.type.trimmedDescription else {
        return false
    }
    return rawType == "String" || rawType == "Swift.String" || rawType == "Swift::String"
}

internal final class PlatformDeadCasePerPlatformVisitor: SyntaxVisitor {
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

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard platformIsPublicAPIEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        guard !platformDeadCasePerPlatformIsStringVocabulary(node) else {
            return .visitChildren
        }
        var caseNames: [Swift::String] = []
        for member in Lint.Syntax.Conditional.members(node.memberBlock) {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }
            for element in caseDecl.elements {
                caseNames.append(element.name.text)
            }
        }
        guard caseNames.count >= 2 else {
            return .visitChildren
        }
        guard platformDeadCasePerPlatformMatchesPlatformPair(caseNames) else {
            return .visitChildren
        }
        let location = converter.location(
            for: node.enumKeyword.positionAfterSkippingLeadingTrivia
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
                identifier: "dead case per platform",
                message: platformDeadCasePerPlatformMessage
            )
        )
        return .visitChildren
    }
}
