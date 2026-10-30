public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `safe attribute undocumented` = Lint.Rule(
        id: "safe attribute undocumented",
        default: .note,
        controls: [
            .init(
                id: "safe attribute undocumented missing",
                source: "@safe public struct Storage {}",
                path: "Sources/Memory Core/UndocumentedSafe.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "safe attribute undocumented disclosed",
                source: "// SAFETY: Safe by construction.\n@safe public struct Storage {}",
                path: "Sources/Memory Core/DocumentedSafe.swift",
                expectation: .clean
            ),
            .init(
                id: "safe attribute undocumented outside sources",
                source: "@safe public struct Storage {}",
                path: "Tests/Memory Tests/SafeFixture.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = MemorySafeAttributeUndocumentedVisitor(
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
internal let memorySafeAttributeUndocumentedMessage: Swift::String =
    "[safe attribute undocumented] [MEM-SAFE-025c]: review prompt, never strict. "
    + "This `@safe` declaration asserts that its unsafe operations uphold an "
    + "invariant ([MEM-SAFE-024] Category A/B/C/D). Sources carry no comments, so "
    + "the invariant belongs in the type's construction and its tests: confirm "
    + "they establish it."

internal final class MemorySafeAttributeUndocumentedVisitor: SyntaxVisitor {
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

    private func safeAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "safe" {
                return attr
            }
        }
        return nil
    }

    private func emit(at attribute: AttributeSyntax) {
        let location = converter.location(for: attribute.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "safe attribute undocumented",
                message: memorySafeAttributeUndocumentedMessage
            )
        )
    }

    private func hasAdjacentInvariantDisclosure<D: DeclSyntaxProtocol>(
        node: D,
        keywordToken: TokenSyntax
    ) -> Bool {
        for trivia in adjacentTriviaBlocks(node: node, keywordToken: keywordToken) {
            if triviaHasInvariantLineComment(trivia)
                || triviaHasSafetyInvariantDocSection(trivia)
            {
                return true
            }
        }
        return false
    }

    private func adjacentTriviaBlocks<D: DeclSyntaxProtocol>(
        node: D,
        keywordToken: TokenSyntax
    ) -> [Trivia] {
        var blocks: [Trivia] = []
        for token in node.tokens(viewMode: .sourceAccurate) {
            blocks.append(token.leadingTrivia)
            if token == keywordToken { break }
        }
        return blocks
    }

    private func triviaHasInvariantLineComment(_ trivia: Trivia) -> Bool {
        memoryTriviaHasAdjacentComment(trivia) { body in
            isInvariantPrefix(body[...])
        }
    }

    private func isInvariantPrefix(_ body: Swift::Substring) -> Bool {
        let lower = body.lowercased()
        return lower.hasPrefix("why:") || lower.hasPrefix("safety:")
    }

    private func triviaHasSafetyInvariantDocSection(_ trivia: Trivia) -> Bool {
        let pieces = Swift::Array(trivia)
        var collected: [Swift::String] = []
        var newlineRun = 0

        for piece in pieces.reversed() {
            switch piece {
            case .newlines(let count), .carriageReturns(let count),
                .carriageReturnLineFeeds(let count):
                newlineRun += count
                if newlineRun >= 2 {
                    return matchesSafetyInvariant(in: collected)
                }

            case .docLineComment(let text):
                newlineRun = 0
                collected.append(text)

            case .docBlockComment(let text):
                newlineRun = 0
                collected.append(text)

            case .lineComment, .blockComment:
                newlineRun = 0
                continue

            case .spaces, .tabs:
                continue

            default:
                continue
            }
        }
        return matchesSafetyInvariant(in: collected)
    }

    private func matchesSafetyInvariant(in pieces: [Swift::String]) -> Bool {
        for text in pieces {
            if text.contains("## Safety Invariant") {
                return true
            }
        }
        return false
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.structKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.classKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.enumKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.actorKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.extensionKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.protocolKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.bindingSpecifier) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.funcKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.initKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.deinitKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.subscriptKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.typealiasKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        if !hasAdjacentInvariantDisclosure(node: node, keywordToken: node.associatedtypeKeyword) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }
}
