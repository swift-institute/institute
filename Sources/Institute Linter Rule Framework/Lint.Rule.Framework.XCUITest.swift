public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `xcuitest reference` = Lint.Rule(
        id: "xcuitest reference",
        default: .warning,
        controls: [
            .init(
                id: "xcuitest reference application",
                source: "let application = XCUIApplication()",
                path: "Tests/Example UI Tests/Launch Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "xcuitest reference lawful Swift Testing suite",
                source: "import Testing\n@Suite struct Launch { @Test func starts() {} }",
                path: "Tests/Example UI Tests/Launch Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "xcuitest reference inside Swift Testing near miss",
                source: "import Testing\n@Test func starts() { _ = XCUIElement.self }",
                path: "Tests/Example UI Tests/Launch Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "xcuitest reference element query",
                source: "let query: XCUIElementQuery",
                path: "Tests/Example UI Tests/Query Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "xcuitest reference XCTest import",
                source: "import XCTest",
                path: "Tests/Example UI Tests/Launch Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "xcuitest reference outside UI test target",
                source: "let application = XCUIApplication()",
                path: "Tests/Example Tests/Launch Tests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard frameworkXCUITestIsUITestTarget(source.file.filePath) else { return [] }
            let visitor = FrameworkXCUITestVisitor(
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
internal let frameworkXCUITestMessage: Swift::String =
    "[xcuitest reference] [TEST-XCUITEST]: in a test target whose directory "
    + "name ends in ` UI Tests`, do not import `XCTest` or use an identifier "
    + "exactly equal to `XCUIApplication`, `XCUIElement`, or `XCUIElementQuery`; "
    + "UI tests use only Swift Testing's `@Test` and `@Suite`."

private let frameworkXCUITestNames: Swift::Set<Swift::String> = [
    "XCUIApplication", "XCUIElement", "XCUIElementQuery",
]

private func frameworkXCUITestIsUITestTarget(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(whereSeparator: { $0 == "/" || $0 == "\\" })
    guard let tests = components.lastIndex(of: "Tests") else { return false }
    let target = components.index(after: tests)
    guard target < components.endIndex else { return false }
    return components[target].hasSuffix(" UI Tests")
}

internal final class FrameworkXCUITestVisitor: SyntaxVisitor {
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

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let module = node.path.trimmedDescription.split(separator: ".").first
        guard module == "XCTest" else { return .visitChildren }
        record(at: node.path.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        guard case .identifier = token.tokenKind,
            frameworkXCUITestNames.contains(token.text)
        else {
            return .visitChildren
        }
        record(at: token.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    private func record(at position: AbsolutePosition) {
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
                identifier: "xcuitest reference",
                message: frameworkXCUITestMessage
            )
        )
    }
}
