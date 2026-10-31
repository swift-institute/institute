public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `suppression reason required` = Lint.Rule(
        id: "suppression reason required",
        default: .error,
        controls: [
            .init(
                id: "suppression reason required missing reason",
                source: """
                    // swift-linter:disable:next malformed suppression directive
                    let value = compute()
                    """,
                path: "Controls/SuppressionReasonRequired.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            reasonless(
                tree: source.tree,
                file: source.file,
                converter: source.converter,
                severity: severity
            )
        }
    )
}

@usableFromInline
internal let `suppression reason required message`: Swift::String =
    "[suppression reason required] [LINT-SUPPRESS-002]: every "
    + "`swift-linter:disable:next` or `swift-linter:disable:line` directive "
    + "must have an immediately associated `// REASON:` continuation with "
    + "non-whitespace prose."

private let suppressionReasonRequiredPrefixes = [
    "// swift-linter:disable:next ",
    "// swift-linter:disable:line ",
]

internal func reasonless(
    tree: SourceFileSyntax,
    file: Source.File,
    converter: SourceLocationConverter,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {
    var comments: [(text: Swift::String, position: AbsolutePosition, line: Swift::Int)] = []

    for token in tree.tokens(viewMode: .sourceAccurate) {
        suppressionReasonRequiredCollect(
            token.leadingTrivia,
            tokenStartPosition: token.position,
            converter: converter,
            into: &comments
        )
        suppressionReasonRequiredCollect(
            token.trailingTrivia,
            tokenStartPosition: token.endPositionBeforeTrailingTrivia,
            converter: converter,
            into: &comments
        )
    }

    var findings: [Diagnostic.Record] = []
    let lines = tree.description.split(separator: "\n", omittingEmptySubsequences: false)

    for comment in comments
    where suppressionReasonRequiredPrefixes.contains(where: comment.text.hasPrefix) {
        guard let prefix = suppressionReasonRequiredPrefixes.first(where: comment.text.hasPrefix),
            comment.text.dropFirst(prefix.count).contains(where: { !$0.isWhitespace })
        else { continue }

        guard comment.line < lines.count else {
            findings.append(
                suppressionReasonRequiredFinding(
                    for: comment,
                    file: file,
                    converter: converter,
                    severity: severity
                )
            )
            continue
        }

        let continuation = lines[comment.line].drop(while: { $0 == " " || $0 == "\t" })
        let reasonPrefix = "// REASON:"
        guard continuation.hasPrefix(reasonPrefix),
            continuation.dropFirst(reasonPrefix.count).contains(where: { !$0.isWhitespace })
        else {
            findings.append(
                suppressionReasonRequiredFinding(
                    for: comment,
                    file: file,
                    converter: converter,
                    severity: severity
                )
            )
            continue
        }
    }
    return findings
}

private func suppressionReasonRequiredCollect(
    _ trivia: Trivia,
    tokenStartPosition: AbsolutePosition,
    converter: SourceLocationConverter,
    into comments: inout [(text: Swift::String, position: AbsolutePosition, line: Swift::Int)]
) {
    var cursor = tokenStartPosition
    for piece in trivia {
        let position = cursor
        defer { cursor = cursor.advanced(by: piece.sourceLength.utf8Length) }
        guard case .lineComment(let text) = piece else { continue }
        comments.append(
            (text, position, converter.location(for: position).line)
        )
    }
}

private func suppressionReasonRequiredFinding(
    for comment: (text: Swift::String, position: AbsolutePosition, line: Swift::Int),
    file: Source.File,
    converter: SourceLocationConverter,
    severity: Diagnostic.Severity
) -> Diagnostic.Record {
    let location = converter.location(for: comment.position)
    return Diagnostic.Record(
        location: Source.Location(
            fileID: file.fileID,
            filePath: file.filePath,
            line: location.line,
            column: location.column
        ),
        severity: severity,
        identifier: "suppression reason required",
        message: `suppression reason required message`
    )
}
