public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `xctest import` = Lint.Rule(
        id: "xctest import",
        default: .warning,
        controls: [
            .init(
                id: "xctest import XCTest",
                source: "import XCTest",
                path: "Sources/Framework Core/XCTestImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "xctest import Testing",
                source: "import Testing",
                path: "Sources/Framework Core/TestingImport.swift",
                expectation: .clean
            ),
            .init(
                id: "xctest import XCTestHelpers",
                source: "import XCTestHelpers",
                path: "Sources/Framework Core/XCTestHelpersImport.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = XCTestImportVisitor(
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
internal let xctestImportMessage: Swift::String =
    "[xctest import] [TEST-001]: institute tests MUST use Swift Testing, "
    + "not XCTest. Replace `import XCTest` + `XCTestCase` subclasses with "
    + "`import Testing` + `@Test` functions inside `@Suite struct Unit {}` "
    + "/ `@Suite struct \\`Edge Case\\` {}`. XCTest also pulls Foundation "
    + "transitively, violating `[PRIM-FOUND-001]` / `[ARCH-LAYER-007]`."

internal final class XCTestImportVisitor: SyntaxVisitor {
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
        let pathText = node.path.trimmedDescription
        guard xctestImportIsXCTestModule(pathText) else {
            return .visitChildren
        }
        let location = converter.location(for: node.path.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "xctest import",
                message: xctestImportMessage
            )
        )
        return .visitChildren
    }
}

private func xctestImportIsXCTestModule(_ pathText: Swift::String) -> Swift::Bool {
    let firstComponent = pathText.split(separator: ".").first.map(Swift::String.init) ?? pathText
    return firstComponent == "XCTest"
}
