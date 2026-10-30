public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `compound type name` = Lint.Rule(
        id: "compound type name",
        default: .warning,
        controls: [
            .init(
                id: "compound type name public compound",
                source: "public struct FileDirectory {}",
                path: "Sources/Naming Core/CompoundType.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound type name single token",
                source: "public struct Directory {}",
                path: "Sources/Naming Core/SingleTokenType.swift",
                expectation: .clean
            ),
            .init(
                id: "compound type name spec namespace",
                source: "public enum RFC_4122 {}",
                path: "Sources/Naming Core/SpecNamespace.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !namingIsPackageManifest(source.file.filePath) else { return [] }
            let visitor = NamingCompoundTypeVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingCompoundTypeMessage: Swift::String =
    "[compound type name] [API-NAME-001]: types MUST use the `Nest.Name` "
    + "pattern. Compound type names like `FileDirectoryWalk` or "
    + "`DirectoryWalk` are forbidden — use the nested form "
    + "(`File.Directory.Walk`). Acronyms (`URL`, `UUID`, `IO`) are "
    + "permitted as single-word names; spec-namespace forms with "
    + "underscores (`RFC_4122`, `ISO_9945`) are exempt per "
    + "`[API-NAME-003]`. `package`-scope declarations and macro decls "
    + "are exempt; `fileprivate`/`private` type declarations including "
    + "members whose effective visibility is reduced by an enclosing "
    + "fileprivate/private type are exempt per "
    + "the API-NAME-002 private-surface-applicability note "
    + "(symmetric extension of the 2026-05-11 [API-NAME-002] amendment "
    + "— consumer-observable surface is the rule's intent and "
    + "fileprivate/private types have none even within the module). "
    + "Stdlib-method-mirror type names that elevate a Swift.Sequence "
    + "(or adjacent) method name to a namespace are exempt per "
    + "`[API-NAME-003]` — see `namingCompoundTypeStdlibMethodMirrorCitations` "
    + "in this rule's source for the citation set. Brand tokens whose "
    + "internal capitals are brand/spec orthography (`GitHub`, `OAuth`, "
    + "`IPv4`, …) are exempt per the #16 Option C ledger — see "
    + "`namingCompoundTypeBrandTokenCitations`; propose additions there "
    + "with the authority that fixes the spelling."

private let namingCompoundTypeStdlibMethodMirrorCitations: [Swift::String: Swift::String] = [
    "CompactMap": "Swift.Sequence.compactMap(_:) / Swift.Optional.compactMap(_:)",
    "FlatMap": "Swift.Sequence.flatMap(_:) / Swift.Optional.flatMap(_:)",
    "ForEach": "Swift.Sequence.forEach(_:)",
    "AllSatisfy": "Swift.Sequence.allSatisfy(_:)",
]

private let namingCompoundTypeBrandTokenCitations: [Swift::String: Swift::String] = [
    "GitHub":
        "github.com brand orthography — ecosystem canonical `GitHub.Owner.ID` (swift-github-standard)",
    "OAuth": "RFC 6749 (The OAuth 2.0 Authorization Framework) — spec's own token spelling",
    "IPv4": "RFC 791 — protocol-version orthography (`IPv4.Address`, swift-rfc-791)",
    "IPv6": "RFC 8200 — protocol-version orthography",
    "PostgreSQL": "postgresql.org brand orthography",
]

internal final class NamingCompoundTypeVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers, syntax: Syntax(node))
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if Naming.Visitor.extends(node.inheritanceClause) {
            return .visitChildren
        }
        check(name: node.name, modifiers: node.modifiers, syntax: Syntax(node))
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers, syntax: Syntax(node))
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers, syntax: Syntax(node))
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers, syntax: Syntax(node))
        return .visitChildren
    }

    override func visit(_: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
        .visitChildren
    }

    private func check(name token: TokenSyntax, modifiers: DeclModifierListSyntax, syntax: Syntax) {
        guard !hasPackageModifier(modifiers) else { return }
        if Naming.hasFileprivateOrPrivateEffective(syntax, modifiers: modifiers) {
            return
        }
        if Naming.isBackticked(token) { return }
        let text = token.text
        guard isCompoundTypeIdentifier(text) else { return }
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
                identifier: "compound type name",
                message: namingCompoundTypeMessage
            )
        )
    }

    private func hasPackageModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.package) {
                return true
            }
        }
        return false
    }

    private func isCompoundTypeIdentifier(_ name: Swift::String) -> Bool {
        namingWordIsCompound(name)
    }
}

internal func namingWordIsCompound(_ name: Swift::String) -> Bool {
    if namingCompoundTypeStdlibMethodMirrorCitations[name] != nil {
        return false
    }
    if namingCompoundTypeBrandTokenCitations[name] != nil {
        return false
    }
    if name.contains("_") { return false }
    guard name.count >= 2 else { return false }
    let chars = Array(name)
    guard chars[0].isUppercase else { return false }
    var words = 1
    var i = 1
    while i < chars.count {
        let previous = chars[chars.index(before: i)]
        let curr = chars[i]
        let nextIndex = chars.index(after: i)
        let next: Swift::Character? = nextIndex < chars.endIndex ? chars[nextIndex] : nil
        if curr.isUppercase {
            if previous.isLowercase {
                words += 1
            } else if previous.isUppercase, let next, next.isLowercase {
                words += 1
            }
        }
        if words >= 2 { return true }
        i += 1
    }
    return false
}
