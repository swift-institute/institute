public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `foundation import` = Lint.Rule(
        id: "foundation import",
        default: .warning,
        controls: [
            .init(
                id: "foundation import main target",
                source: "import Foundation",
                path: "Sources/Foundation Core/FoundationImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import public import",
                source: "public import Foundation",
                path: "Sources/Foundation Core/PublicImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import exported import",
                source: "@_exported import Foundation",
                path: "Sources/Foundation Core/ExportedImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import networking module",
                source: "import FoundationNetworking",
                path: "Sources/Foundation Core/NetworkingImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import xml module",
                source: "import FoundationXML",
                path: "Sources/Foundation Core/XMLImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import essentials module",
                source: "import FoundationEssentials",
                path: "Sources/Foundation Core/EssentialsImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import scoped declaration import",
                source: "import struct Foundation.Date",
                path: "Sources/Foundation Core/ScopedImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation import test target",
                source: "import Foundation",
                path: "Tests/Foundation Core Tests/FoundationImport.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation import nested package test target",
                source: "import Foundation",
                path: "Nested/Tests/Foundation Core Tests/FoundationImport.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation import package manifest",
                source: "import Foundation",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation import unrelated module",
                source: "import Binary",
                path: "Sources/Foundation Core/BinaryPrimitivesImport.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation import integration target",
                source: "import Foundation",
                path: "Sources/Foundation Foundation Integration/FoundationImport.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !foundationImportIsInsideFoundationIntegrationTarget(source.file.filePath) else {
                return []
            }
            guard !foundationImportIsOutsideMainTarget(source.file.filePath) else {
                return []
            }
            guard !foundationImportIsPackageManifest(source.file.filePath) else {
                return []
            }
            let visitor = FoundationImportVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let foundationIntegrationTargetSuffix: Swift::String = " Foundation Integration"

private func foundationImportIsInsideFoundationIntegrationTarget(
    _ filePath: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { $0.hasSuffix(foundationIntegrationTargetSuffix) }
}

private let foundationImportNonMainTargetRoots: [Swift::String] = [
    "Tests",
    "Experiments",
    "Examples",
]

private func foundationImportIsOutsideMainTarget(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { component in
        foundationImportNonMainTargetRoots.contains(Swift::String(component))
    }
}

private func foundationImportIsPackageManifest(_ filePath: Swift::String) -> Swift::Bool {
    guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
    else { return false }
    if filename == "Package.swift" { return true }
    return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}

@usableFromInline
internal let foundationImportMessage: Swift::String =
    "[foundation import] [ARCH-LAYER-007]: no package's main target may import "
    + "the Foundation module family (`Foundation`, `FoundationEssentials`, "
    + "`FoundationNetworking`, `FoundationXML`) — at ANY of the five layers, not "
    + "just primitives. Use institute primitives (`Time`, "
    + "`Binary`, etc.) instead. Foundation-adjacent interop belongs in "
    + "a separately-declared `* Foundation Integration` subtarget that consumers "
    + "opt into, never the main target. (`[PRIM-FOUND-001]` is the Layer-1 "
    + "specialization of this rule; it is not a primitives-only rule.)"

internal final class FoundationImportVisitor: SyntaxVisitor {
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
        guard foundationImportIsFoundationModule(pathText) else {
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
                identifier: "foundation import",
                message: foundationImportMessage
            )
        )
        return .visitChildren
    }
}

private let foundationModuleFamily: Swift::Set<Swift::String> = [
    "Foundation",
    "FoundationEssentials",
    "FoundationNetworking",
    "FoundationXML",
]

private func foundationImportIsFoundationModule(_ pathText: Swift::String) -> Swift::Bool {
    let firstComponent = pathText.split(separator: ".").first.map(Swift::String.init) ?? pathText
    return foundationModuleFamily.contains(firstComponent)
}
