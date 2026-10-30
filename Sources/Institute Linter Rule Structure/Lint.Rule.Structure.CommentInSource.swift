public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `comment in source` = Lint.Rule(
        id: "comment in source",
        default: .warning,
        controls: [
            .init(
                id: "comment in source line",
                source: "// Implementation note\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment in source documentation",
                source: "/// A value.\n/** A block. */\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment in source disclosure markers",
                source: "// SAFETY: Allocated once.\n// and never freed.\n// WHY: The C API takes a pointer.\n"
                    + "// WHEN TO REMOVE: When the compiler lands it.\n// REMOVE-WHEN: Fixed upstream.\n"
                    + "// TRACKING: swift-institute/Issues#1\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment in source marker near miss",
                source: "// Safety: lower case\n// SAFETY: ok\n\n// detached\n/* SAFETY: block */\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(3)
            ),
            .init(
                id: "comment in source block and trailing",
                source: "/* block */\nlet value = 1 // trailing",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "comment in source directive",
                source: "// swift-linter:disable:next comment in source\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment in source directive reason",
                source: "func f() {\n    // swift-linter:disable:next do throws for typed catch\n    // REASON: Task.sleep throws untyped\n    try await Task.sleep(for: .seconds(1))\n}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment in source reason without directive",
                source: "// REASON: no directive above\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment in source reason after a blank line",
                source: "// swift-linter:disable:next comment in source\n\n// REASON: detached\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment in source string",
                source: "let text = \"// not a comment\"",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment in source test",
                source: "// Test note\nstruct Value {}",
                path: "Tests/Structure Core Tests/Value.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = StructureCommentInSourceVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return .unchanged
            }
            let original = source.tree.description
            let contents = StructureCommentInSourceRewriter(viewMode: .sourceAccurate)
                .rewrite(Syntax(source.tree)).description
            return contents == original
                ? .unchanged
                : .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let structureCommentInSourceMessage: Swift::String =
    "[comment in source] [SOURCE-NO-COMMENTS]: sources carry no plain `//` or "
    + "`/* */` comments; names, types and tests carry the meaning. Admitted: `///` "
    + "and `/** */` documentation, the disclosure lines the skills require "
    + "(`// SAFETY:`, `// WHY:`, `// TRACKING:`, `// WHEN TO REMOVE:`, "
    + "`// REMOVE-WHEN:`, with their continuation lines), and `// swift-linter:` "
    + "directives with their `// REASON:` line. This checks that a comment is one "
    + "of these, not that what it says is true."

internal final class StructureCommentInSourceVisitor: SyntaxVisitor {
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
        scan(token.leadingTrivia, from: token.position)
        scan(token.trailingTrivia, from: token.endPositionBeforeTrailingTrivia)
        return .visitChildren
    }

    private func scan(_ trivia: Trivia, from start: AbsolutePosition) {
        var position = start
        let admitted = structureCommentInSourceAdmittedIndices(trivia)
        for (index, piece) in trivia.enumerated() {
            defer { position = position.advanced(by: piece.sourceLength.utf8Length) }
            guard !admitted.contains(index) else { continue }
            let text: Swift::String? =
                switch piece {
                case .lineComment(let text): text
                case .docLineComment(let text), .blockComment(let text), .docBlockComment(let text): text
                default: nil
                }
            guard let text, !text.hasPrefix("// swift-linter:") else { continue }
            let location = converter.location(for: position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "comment in source",
                    message: structureCommentInSourceMessage
                )
            )
        }
    }
}

internal final class StructureCommentInSourceRewriter: SyntaxRewriter {
    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        token
            .with(\.leadingTrivia, stripped(token.leadingTrivia, leading: true))
            .with(\.trailingTrivia, stripped(token.trailingTrivia, leading: false))
    }

    private func stripped(_ trivia: Trivia, leading: Swift::Bool) -> Trivia {
        var pieces: [TriviaPiece] = []
        var skipNewline = false
        let admitted = structureCommentInSourceAdmittedIndices(trivia)
        for (index, piece) in trivia.enumerated() {
            if skipNewline {
                skipNewline = false
                switch piece {
                case .newlines(let count):
                    if count > 1 { pieces.append(.newlines(count - 1)) }
                    continue
                case .carriageReturnLineFeeds(let count):
                    if count > 1 { pieces.append(.carriageReturnLineFeeds(count - 1)) }
                    continue
                default:
                    break
                }
            }
            guard structureCommentInSourceIsRemovable(piece), !admitted.contains(index) else {
                pieces.append(piece)
                continue
            }
            while let last = pieces.last, last.isSpaceOrTab {
                pieces.removeLast()
            }
            skipNewline = leading && (pieces.last.map(\.isNewline) ?? true)
        }
        return Trivia(pieces: pieces)
    }
}

internal let structureCommentInSourceMarkers: [Swift::String] = [
    "SAFETY:", "WHY:", "TRACKING:", "WHEN TO REMOVE:", "REMOVE-WHEN:",
]

internal func structureCommentInSourceIsMarker(_ text: Swift::String) -> Swift::Bool {
    guard text.hasPrefix("//") else { return false }
    let body = text.dropFirst(2).drop { $0 == " " || $0 == "\t" }
    return structureCommentInSourceMarkers.contains { body.hasPrefix($0) }
}

internal func structureCommentInSourceAdmittedIndices(_ trivia: Trivia) -> Swift::Set<Swift::Int> {
    let pieces = Array(trivia)
    var admitted: Swift::Set<Swift::Int> = []
    for (index, piece) in pieces.enumerated() {
        switch piece {
        case .docLineComment, .docBlockComment:
            admitted.insert(index)
        case .lineComment(let text):
            if structureCommentInSourceIsMarker(text) {
                admitted.insert(index)
                continue
            }
            guard let previous = structureCommentInSourcePreviousLine(pieces, before: index),
                case .lineComment(let prior) = pieces[previous]
            else { continue }
            if text.hasPrefix("// REASON:"), prior.hasPrefix("// swift-linter:disable:") {
                admitted.insert(index)
            } else if admitted.contains(previous), !text.hasPrefix("// swift-linter:") {
                admitted.insert(index)
            }
        default:
            continue
        }
    }
    return admitted
}

internal func structureCommentInSourcePreviousLine(
    _ pieces: [TriviaPiece],
    before index: Swift::Int
) -> Swift::Int? {
    var cursor = index - 1
    while cursor >= 0, pieces[cursor].isSpaceOrTab { cursor -= 1 }
    guard cursor >= 0 else { return nil }
    switch pieces[cursor] {
    case .newlines(1), .carriageReturnLineFeeds(1): cursor -= 1
    default: return nil
    }
    while cursor >= 0, pieces[cursor].isSpaceOrTab { cursor -= 1 }
    return cursor >= 0 ? cursor : nil
}

internal func structureCommentInSourceIsRemovable(_ piece: TriviaPiece) -> Swift::Bool {
    switch piece {
    case .lineComment(let text): !text.hasPrefix("// swift-linter:")
    case .docLineComment, .blockComment, .docBlockComment: true
    default: false
    }
}

extension TriviaPiece {
    fileprivate var isSpaceOrTab: Swift::Bool {
        switch self {
        case .spaces, .tabs: true
        default: false
        }
    }
}
