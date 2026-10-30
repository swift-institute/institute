internal import Byte
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `diagnostic message format` = Lint.Rule(
        id: "diagnostic message format",
        default: .warning,
        controls: [
            .init(
                id: "diagnostic message format malformed",
                source: "enum Demo { static let message = \"prefer typed throws\" }",
                path: "Sources/Controls/Lint.Rule.Demo.Example.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "diagnostic message format conforming",
                source: "enum Demo { static let message = \"[try_optional] "
                    + "[API-ERR-001]: prefer typed throws\" }",
                path: "Sources/Controls/Lint.Rule.Demo.Example.swift",
                expectation: .clean
            ),
            .init(
                id: "diagnostic message format helper scope",
                source: "enum Demo { static let message = \"prefer typed throws\" }",
                path: "Sources/Controls/Helper.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard namingDiagnosticFormatIsLintRuleSource(source.file.filePath) else {
                return []
            }
            let visitor = NamingDiagnosticFormatVisitor(
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
internal let namingDiagnosticFormatMessage: Swift::String =
    "[diagnostic message format] [API-NAME-009]: `static let message` does "
    + "not follow the educational-diagnostic format `[<rule_id>] <citation>: "
    + "<description>`. The leading bracket carries the rule id (snake_case or "
    + "kebab-case), the citation is a skill rule ID (`[API-ERR-001]`), a "
    + "feedback-memory filename (`feedback_no_try_optional`) or a research-doc "
    + "path (`Research/typed-throws-rationale.md`), and a `: ` separates the "
    + "citation from the description."

internal func namingDiagnosticFormatIsLintRuleSource(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard let filename = components.last else { return false }
    guard components.dropLast().contains("Sources") else { return false }
    guard !components.contains(where: { $0.hasPrefix(".") }) else { return false }
    guard filename.hasSuffix(".swift") else { return false }
    let stem = Swift::String(filename.dropLast(".swift".count))
    guard stem.hasPrefix("Lint.Rule.") else { return false }
    return stem.filter { $0 == "." }.count >= 3
}

internal func namingDiagnosticFormatMatches(_ text: Swift::String) -> Swift::Bool {
    var bytes = [Byte](utf8: text)[...]
    guard bytes.first?.bitPattern == 0x5B else { return false }
    bytes = bytes.dropFirst()
    guard let first = bytes.first,
        (first.bitPattern >= 0x61 && first.bitPattern <= 0x7A) || first.bitPattern == 0x5F
    else { return false }
    bytes = bytes.dropFirst()
    while let byte = bytes.first, namingDiagnosticFormatIsWord(byte) || byte.bitPattern == 0x2D {
        bytes = bytes.dropFirst()
    }
    guard bytes.first?.bitPattern == 0x5D else { return false }
    bytes = bytes.dropFirst()
    guard let space = bytes.first, namingDiagnosticFormatIsWhitespace(space)
    else { return false }
    while let byte = bytes.first, namingDiagnosticFormatIsWhitespace(byte) {
        bytes = bytes.dropFirst()
    }
    guard let citationFirst = bytes.first, citationFirst.bitPattern != 0x3A else { return false }
    bytes = bytes.dropFirst()
    while let byte = bytes.first, byte.bitPattern != 0x3A {
        bytes = bytes.dropFirst()
    }
    guard bytes.first?.bitPattern == 0x3A else { return false }
    bytes = bytes.dropFirst()
    guard let after = bytes.first else { return false }
    return namingDiagnosticFormatIsWhitespace(after)
}

private func namingDiagnosticFormatIsWord(_ byte: Byte) -> Swift::Bool {
    (byte.bitPattern >= 0x61 && byte.bitPattern <= 0x7A) || (byte.bitPattern >= 0x41 && byte.bitPattern <= 0x5A)
        || (byte.bitPattern >= 0x30 && byte.bitPattern <= 0x39) || byte.bitPattern == 0x5F
}

private func namingDiagnosticFormatIsWhitespace(_ byte: Byte) -> Swift::Bool {
    byte.bitPattern == 0x20 || byte.bitPattern == 0x09 || byte.bitPattern == 0x0A || byte.bitPattern == 0x0D
        || byte.bitPattern == 0x0B || byte.bitPattern == 0x0C
}

internal final class NamingDiagnosticFormatVisitor: SyntaxVisitor {
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

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.bindingSpecifier.tokenKind == .keyword(.let) else { return .visitChildren }
        guard node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
        else { return .visitChildren }
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                pattern.identifier.text == "message",
                let initializer = binding.initializer
            else { continue }
            guard let concatenated = namingDiagnosticFormatConcatenatedLiteral(initializer.value)
            else { continue }
            if !namingDiagnosticFormatMatches(concatenated) {
                let position = binding.pattern.positionAfterSkippingLeadingTrivia
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
                        identifier: "diagnostic message format",
                        message: namingDiagnosticFormatMessage
                    )
                )
            }
        }
        return .visitChildren
    }
}

internal func namingDiagnosticFormatConcatenatedLiteral(
    _ expression: ExprSyntax
) -> Swift::String? {
    if let literal = expression.as(StringLiteralExprSyntax.self) {
        return namingDiagnosticFormatLiteralText(literal)
    }
    if let sequence = expression.as(SequenceExprSyntax.self) {
        var parts: [Swift::String] = []
        for (index, element) in sequence.elements.enumerated() {
            if index % 2 == 0 {
                guard let literal = element.as(StringLiteralExprSyntax.self) else {
                    return parts.isEmpty ? nil : parts.joined()
                }
                parts.append(namingDiagnosticFormatLiteralText(literal))
            } else {
                guard let binaryOperator = element.as(BinaryOperatorExprSyntax.self),
                    binaryOperator.operator.text == "+"
                else {
                    return parts.isEmpty ? nil : parts.joined()
                }
            }
        }
        return parts.isEmpty ? nil : parts.joined()
    }
    if let infix = expression.as(InfixOperatorExprSyntax.self) {
        guard let binaryOperator = infix.operator.as(BinaryOperatorExprSyntax.self),
            binaryOperator.operator.text == "+",
            let left = namingDiagnosticFormatConcatenatedLiteral(infix.leftOperand)
        else { return nil }
        guard let right = namingDiagnosticFormatConcatenatedLiteral(infix.rightOperand) else {
            return left
        }
        return left + right
    }
    return nil
}

private func namingDiagnosticFormatLiteralText(
    _ literal: StringLiteralExprSyntax
) -> Swift::String {
    var text = ""
    for segment in literal.segments {
        switch segment {
        case .stringSegment(let stringSegment):
            text += stringSegment.content.text
                .replacing("\\n", with: "\n")
                .replacing("\\t", with: "\t")
                .replacing("\\\"", with: "\"")
                .replacing("\\\\", with: "\\")

        case .expressionSegment(let expressionSegment):
            text += expressionSegment.trimmedDescription
        }
    }
    return text
}
