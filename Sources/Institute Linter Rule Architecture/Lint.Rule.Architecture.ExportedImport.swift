public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `exported import` = Lint.Rule(
        id: "exported import",
        default: .warning,
        controls: [
            .init(
                id: "exported import re-export",
                source: "@_exported public import Owner",
                path: "Sources/Architecture Consumer/Consumer.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "exported import exports file",
                source: "@_exported public import Owner",
                path: "Sources/Architecture Consumer/exports.swift",
                expectation: .clean
            ),
            .init(
                id: "exported import exports file near miss",
                source: "@_exported import Owner\n@_exported public import struct Owner.Value",
                path: "Sources/Architecture Consumer/exports.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "exported import exports-like file name",
                source: "@_exported public import Owner",
                path: "Sources/Architecture Consumer/Owner exports.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "exported import plain",
                source: "public import Owner",
                path: "Sources/Architecture Consumer/Consumer.swift",
                expectation: .clean
            ),
            .init(
                id: "exported import test",
                source: "@_exported import Owner",
                path: "Tests/Architecture Consumer Tests/exports.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = ArchitectureExportedImportVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                exportsFile: architectureExportedImportIsTargetExportsFile(path)
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let architectureExportedImportMessage: Swift::String =
    "[exported import] [SOURCE-EXPORTED-IMPORT]: `@_exported` re-exports a module "
    + "to every consumer and hides the real dependency edge; consumers import "
    + "what they use. The one admitted re-export is a whole-module "
    + "`@_exported public import` in a target's own `Sources/<Target>/exports.swift`."

internal func architectureExportedImportIsTargetExportsFile(_ path: Swift::String) -> Swift::Bool {
    let components = path.split(separator: "/", omittingEmptySubsequences: true)
    return components.last == "exports.swift"
        && components.dropLast(2).last == "Sources"
}

internal final class ArchitectureExportedImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let exportsFile: Swift::Bool
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        exportsFile: Swift::Bool
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.exportsFile = exportsFile
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if exportsFile, node.importKindSpecifier == nil,
            node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) })
        {
            return .skipChildren
        }
        for element in node.attributes {
            guard let attribute = element.as(AttributeSyntax.self),
                attribute.attributeName.trimmedDescription == "_exported"
            else { continue }
            let location = converter.location(for: attribute.positionAfterSkippingLeadingTrivia)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "exported import",
                    message: architectureExportedImportMessage
                )
            )
        }
        return .skipChildren
    }
}
