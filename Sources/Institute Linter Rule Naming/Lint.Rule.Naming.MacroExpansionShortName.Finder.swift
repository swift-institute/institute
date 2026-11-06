internal import SwiftParser
internal import SwiftSyntax

internal final class NamingMacroExpansionShortNameFinder: SyntaxVisitor {
    var matches: [(literal: StringLiteralExprSyntax, name: Swift::String)] = []

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let generatedSource = namingMacroExpansionShortNameGeneratedSource(node)
        let parsed = Parser.parse(source: generatedSource)
        let typeFinder = NamingMacroExpansionShortNameTypeFinder(viewMode: .sourceAccurate)
        typeFinder.walk(parsed)
        var reported: Swift::Set<Swift::String> = []
        for name in typeFinder.matches where reported.insert(name).inserted {
            matches.append((literal: node, name: name))
        }
        return .skipChildren
    }
}

private func namingMacroExpansionShortNameGeneratedSource(
    _ node: StringLiteralExprSyntax
) -> Swift::String {
    var source = ""
    for segment in node.segments {
        switch segment {
        case .stringSegment(let text):
            source += namingMacroExpansionShortNameUnescaped(
                text.content.text,
                delimiter: node.openingPounds?.text ?? ""
            )
        case .expressionSegment:
            source += "__macro_interpolation__"
        }
    }
    return source
}

/// The text a string segment stands for: `\n`, `\t`, `\r`, `\0`, `\\`, `\"`, `\'` and
/// `\u{…}` are decoded, so `"\n"` reads as a line break, not as a key path to `n`. A raw
/// literal's escapes carry its `#` delimiter.
private func namingMacroExpansionShortNameUnescaped(
    _ text: Swift::String,
    delimiter: Swift::String
) -> Swift::String {
    let escape = "\\" + delimiter
    guard text.contains(escape) else { return text }
    var result = ""
    var rest = Swift::Substring(text)
    while let range = rest.firstRange(of: escape) {
        result += rest[..<range.lowerBound]
        rest = rest[range.upperBound...]
        guard let next = rest.first else {
            result += escape
            break
        }
        rest = rest.dropFirst()
        switch next {
        case "n": result += "\n"
        case "t": result += "\t"
        case "r": result += "\r"
        case "0": result += "\0"
        case "\\", "\"", "'": result.append(next)
        case "u":
            guard rest.first == "{", let close = rest.firstIndex(of: "}"),
                let value = Swift::UInt32(rest[rest.index(after: rest.startIndex)..<close], radix: 16),
                let scalar = Swift::Unicode.Scalar(value)
            else {
                result += escape + "u"
                continue
            }
            result.unicodeScalars.append(scalar)
            rest = rest[rest.index(after: close)...]
        default:
            result += " "
        }
    }
    result += rest
    return result
}
