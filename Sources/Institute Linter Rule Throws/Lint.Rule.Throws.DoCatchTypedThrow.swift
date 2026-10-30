public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `do throws for typed catch with throw` = Lint.Rule(
        id: "do throws for typed catch with throw",
        default: .warning,
        controls: [
            .init(
                id: "do throws for typed catch with throw bare do throw",
                source: "do { throw Read.Error.invalid } catch { handle(error) }",
                path: "Sources/Throws Consumer/BareDoThrow.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "do throws for typed catch with throw typed do",
                source: "do throws(Read.Error) { throw .invalid } catch { handle(error) }",
                path: "Sources/Throws Consumer/TypedDoThrow.swift",
                expectation: .clean
            ),
            .init(
                id: "do throws for typed catch with throw propagating try",
                source: "do { try load(); throw Read.Error.invalid } catch { handle(error) }",
                path: "Sources/Throws Consumer/DoTryAndThrow.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsDoCatchTypedThrowVisitor(
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
internal let throwsDoCatchTypedThrowMessage: Swift::String =
    "[do throws for typed catch with throw] [IMPL-075]: bare `do { throw … } "
    + "catch { … }` erases the concrete error type. Use "
    + "`do throws(E) { throw … } catch { … }`."

internal final class ThrowsDoCatchTypedThrowVisitor: SyntaxVisitor {
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

    override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.throwsClause != nil { return .visitChildren }
        guard !node.catchClauses.isEmpty else { return .visitChildren }
        let throwFinder = ThrowsDoCatchThrowFinder(viewMode: .sourceAccurate)
        throwFinder.walk(node.body)
        guard throwFinder.found else { return .visitChildren }
        let tryFinder = ThrowsDoCatchTypedThrowTryFinder(viewMode: .sourceAccurate)
        tryFinder.walk(node.body)
        guard !tryFinder.found else { return .visitChildren }
        let location = converter.location(for: node.doKeyword.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "do throws for typed catch with throw",
                message: throwsDoCatchTypedThrowMessage
            )
        )
        return .visitChildren
    }
}
