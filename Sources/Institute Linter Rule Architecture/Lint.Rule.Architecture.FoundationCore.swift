public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `architecture foundation type` = Lint.Rule(
        id: "architecture foundation type",
        default: .warning,
        controls: [
            .init(
                id: "architecture foundation type qualified use",
                source: "public var payload: Foundation.Data",
                path: "Sources/Architecture Core/QualifiedUse.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture foundation type unqualified short name",
                source: "public var payload: Data",
                path: "Sources/Architecture Core/UnqualifiedShortName.swift",
                expectation: .clean
            ),
            .init(
                id: "architecture foundation type integration exemption",
                source: "public var payload: Foundation.Data",
                path: "Sources/Architecture Foundation Integration/QualifiedUse.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard
                !architectureFoundationTypeIsInsideFoundationIntegrationTarget(source.file.filePath)
            else {
                return []
            }
            guard !architectureFoundationTypeIsOutsideMainTarget(source.file.filePath) else {
                return []
            }
            guard !architectureFoundationTypeIsPackageManifest(source.file.filePath) else {
                return []
            }
            let visitor = ArchitectureFoundationTypeVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let architectureFoundationTypeModuleFamily: [Swift::String] = [
    "Foundation",
    "FoundationEssentials",
    "FoundationNetworking",
    "FoundationXML",
]

private func architectureFoundationTypeIsFoundationClassName(
    _ name: Swift::String
) -> Swift::Bool {
    guard name.count > 2, name.hasPrefix("NS") else { return false }
    let remainder = name.dropFirst(2)
    guard let first = remainder.first, first.isUppercase else { return false }
    return remainder.contains { $0.isLowercase }
}

private let architectureFoundationTypeIntegrationTargetSuffix: Swift::String =
    " Foundation Integration"

private func architectureFoundationTypeIsInsideFoundationIntegrationTarget(
    _ filePath: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains {
        $0.hasSuffix(architectureFoundationTypeIntegrationTargetSuffix)
    }
}

private let architectureFoundationTypeNonMainTargetRoots: [Swift::String] = [
    "Tests",
    "Experiments",
    "Examples",
]

private func architectureFoundationTypeIsOutsideMainTarget(
    _ filePath: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { component in
        architectureFoundationTypeNonMainTargetRoots.contains(Swift::String(component))
    }
}

private func architectureFoundationTypeIsPackageManifest(
    _ filePath: Swift::String
) -> Swift::Bool {
    guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
    else { return false }
    if filename == "Package.swift" { return true }
    return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}

private let architectureFoundationTypeMessage: Swift::String =
    "[architecture foundation type] [ARCH-LAYER-007]: no package's main target "
    + "may USE Foundation types — Foundation-freedom governs use, not just the "
    + "import statement, and a transitively re-exported Foundation module makes "
    + "its types nameable without any local import for the import rule to see. "
    + "Use institute primitives instead; Foundation-adjacent interop belongs in "
    + "a separately-declared `* Foundation Integration` subtarget."

internal final class ArchitectureFoundationTypeVisitor: SyntaxVisitor {
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
                identifier: "architecture foundation type",
                message: architectureFoundationTypeMessage
            )
        )
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if architectureFoundationTypeIsFoundationClassName(node.name.text) {
            record(at: node.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.baseType.as(IdentifierTypeSyntax.self),
            architectureFoundationTypeModuleFamily.contains(base.name.text)
        {
            record(at: node.positionAfterSkippingLeadingTrivia)
            return .skipChildren
        }
        return .visitChildren
    }
}
