public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `bitpattern rawvalue chain` = Lint.Rule(
        id: "bitpattern rawvalue chain",
        default: .warning,
        controls: [
            .init(
                id: "bitpattern rawvalue chain labeled raw value",
                source: "let value = Int(bitPattern: index.rawValue)",
                path: "Sources/Raw Value Core/BitPatternRawValue.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bitpattern rawvalue chain typed argument",
                source: "let value = Int(bitPattern: index)",
                path: "Sources/Raw Value Core/BitPatternTyped.swift",
                expectation: .clean
            ),
            .init(
                id: "bitpattern rawvalue chain different label",
                source: "let value = Int(other: index.rawValue)",
                path: "Sources/Raw Value Core/OtherInitializer.swift",
                expectation: .clean
            ),
            .init(
                id: "bitpattern rawvalue chain nested in an expression",
                source: "let value = Int8(bitPattern: UInt8(v.rawValue >> 8))",
                path: "Sources/RawValue Consumer/Shifted.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = RawValueBitPatternVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let bitpatternRawvalueChainMessage: Swift::String =
    "[bitpattern rawvalue chain] [CONV-016]: `init(bitPattern:)` whose argument chains "
    + "through `.rawValue` — including `Int(...)`, `UInt(...)`, `Int.init(...)`, "
    + "`self.init(...)`, and other syntactic equivalents — bypasses the canonical "
    + "preference hierarchy. Prefer `.retag()` / `.map()` (Tier 1/2) before resorting "
    + "to the [INFRA-002] integration overload — and when you do use the overload, "
    + "pass the typed value directly: `Int(bitPattern: foo)` not "
    + "`Int(bitPattern: foo.rawValue)`. If this site IS the [INFRA-002] integration "
    + "overload definition itself, escalate to supervisor and apply "
    + "`// swift-linter:disable:next bitpattern rawvalue chain  // reason: <citation>`."

internal final class RawValueBitPatternVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        for arg in node.arguments {
            guard let label = arg.label, label.text == "bitPattern" else { continue }
            guard Self.containsRawValueAccess(arg.expression) else { continue }
            let location = converter.location(for: label.positionAfterSkippingLeadingTrivia)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "bitpattern rawvalue chain",
                    message: bitpatternRawvalueChainMessage
                )
            )
        }
        return .visitChildren
    }

    /// The argument *is* a `.rawValue` access (through parentheses), not an
    /// expression that merely uses one, such as `UInt8(v.rawValue >> 8)`.
    private static func containsRawValueAccess(_ expr: ExprSyntax) -> Swift::Bool {
        var current = expr
        while let tuple = current.as(TupleExprSyntax.self), tuple.elements.count == 1,
            let only = tuple.elements.first, only.label == nil
        {
            current = only.expression
        }
        guard let member = current.as(MemberAccessExprSyntax.self) else { return false }
        return member.declName.baseName.text == "rawValue"
    }
}
