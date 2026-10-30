public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `architecture import boundary` = Lint.Rule(
        id: "architecture import boundary",
        default: .warning,
        controls: [
            .init(
                id: "architecture import boundary ordinary reexport",
                source: "@_exported import Binary",
                path: "Sources/Architecture Core/OrdinaryReexport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture import boundary plain import",
                source: "public import Binary",
                path: "Sources/Architecture Core/PlainImport.swift",
                expectation: .clean
            ),
            .init(
                id: "architecture import boundary umbrella exemption",
                source: "@_exported public import Binary",
                path: "Sources/Architecture Core/exports.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !architectureImportBoundaryIsUmbrellaExportsFile(source.file.filePath) else {
                return []
            }
            guard !architectureImportBoundaryIsOutsideMainTarget(source.file.filePath) else {
                return []
            }
            let visitor = ArchitectureImportBoundaryVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let architectureImportBoundaryUmbrellaFilename: Swift::String = "exports.swift"

private func architectureImportBoundaryIsUmbrellaExportsFile(
    _ filePath: Swift::String
) -> Swift::Bool {
    guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
    else { return false }
    return filename == architectureImportBoundaryUmbrellaFilename
}

private let architectureImportBoundaryNonMainTargetRoots: [Swift::String] = [
    "Tests",
    "Experiments",
    "Examples",
]

private func architectureImportBoundaryIsOutsideMainTarget(
    _ filePath: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { component in
        architectureImportBoundaryNonMainTargetRoots.contains(Swift::String(component))
    }
}

private let architectureImportBoundaryMessage: Swift::String =
    "[architecture import boundary] [ARCH-FOUND-001]: `@_exported import` "
    + "re-exports a dependency edge that import-based architecture measurement "
    + "cannot see from consumers. Re-exports belong in the target's single "
    + "umbrella `exports.swift`, never in ordinary source files. If the module "
    + "is needed here, import it plainly; if the target's public surface should "
    + "re-export it, move the `@_exported import` to `exports.swift`."

internal final class ArchitectureImportBoundaryVisitor: SyntaxVisitor {
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
        let isExported = node.attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == "_exported"
        }
        guard isExported else { return .visitChildren }
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
                identifier: "architecture import boundary",
                message: architectureImportBoundaryMessage
            )
        )
        return .visitChildren
    }
}
