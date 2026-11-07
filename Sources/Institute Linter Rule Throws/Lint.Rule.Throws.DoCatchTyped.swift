public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `do throws for typed catch` = Lint.Rule(
        id: "do throws for typed catch",
        default: .warning,
        suppression: .next,
        controls: [
            .init(
                id: "do throws for typed catch bare do try",
                source: "do { try load() } catch { handle(error) }",
                path: "Sources/Throws Consumer/BareDoTry.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "do throws for typed catch typed do",
                source: "do throws(Read.Error) { try load() } catch { handle(error) }",
                path: "Sources/Throws Consumer/TypedDoTry.swift",
                expectation: .clean
            ),
            .init(
                id: "do throws for typed catch optional try",
                source: "do { _ = try? load() } catch { handle(error) }",
                path: "Sources/Throws Consumer/OptionalDoTry.swift",
                expectation: .clean
            ),
            .init(
                id: "do throws for typed catch error unused",
                source: "do { try load() } catch { fallback() }",
                path: "Sources/Throws Consumer/UnusedErrorDoTry.swift",
                expectation: .clean
            ),
            .init(
                id: "do throws for typed catch cast pattern",
                source: "do { try load() } catch let failure as Read.Error { handle(failure) } catch { log(error) }",
                path: "Sources/Throws Consumer/CastPatternDoTry.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsDoCatchTypedVisitor(
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
internal let throwsDoCatchTypedMessage: Swift::String =
    "[do throws for typed catch] [IMPL-075]: bare `do { try ... } catch { }` "
    + "erases the concrete error type. Use `do throws(E) { try ... } catch { }` "
    + "to preserve `E` in the catch binding."
    + " If the callee throws UNTYPED (cross-module APIs such as "
    + "`FileManager.removeItem(at:)` or `try await task.value`) there is no `E` "
    + "to name and no construct satisfies every rule — `try?` fires "
    + "feedback_prefer_typed_throws_over_try_optional and `do throws(any Error)` "
    + "fires feedback_no_existential_throws. Apply "
    + "`// swift-linter:disable:next do throws for typed catch` with a `// REASON:` "
    + "naming the untyped callee. Where a typed `E` DOES exist both rules are "
    + "satisfiable together, so this rule is not softened for the typed case."

internal final class ThrowsDoCatchTypedVisitor: SyntaxVisitor {
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
        let finder = ThrowsDoCatchTryFinder(viewMode: .sourceAccurate)
        finder.walk(node.body)
        guard finder.found else { return .visitChildren }
        // A catch that matches by pattern already names its types, and a
        // catch that never reads `error` loses nothing to the erasure.
        guard node.catchClauses.allSatisfy({ $0.catchItems.isEmpty }) else { return .visitChildren }
        let reader = ThrowsDoCatchErrorReader(viewMode: .sourceAccurate)
        for clause in node.catchClauses { reader.walk(clause.body) }
        guard reader.found else { return .visitChildren }
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
                identifier: "do throws for typed catch",
                message: throwsDoCatchTypedMessage
            )
        )
        return .visitChildren
    }
}

private final class ThrowsDoCatchErrorReader: SyntaxVisitor {
    var found = false

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        if node.baseName.text == "error" { found = true }
        return .skipChildren
    }
}
