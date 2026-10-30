public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `platform layer import` = Lint.Rule(
        id: "platform layer import",
        default: .warning,
        controls: [
            .init(
                id: "platform layer import direct policy module",
                source: "import POSIX_Kernel",
                path: "Sources/Consumer Core/DirectPolicyImport.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import unifier surface",
                source: "import Kernel",
                path: "Sources/Consumer Core/KernelImport.swift",
                expectation: .clean
            ),
            .init(
                id: "platform layer import iso 9945 utility namespace",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet name: ISO_9945.Utility.Name? = nil",
                path: "Sources/Consumer Core/UtilityImport.swift",
                expectation: .clean
            ),
            .init(
                id: "platform layer import iso 9945 glob namespace",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Glob\nlet glob = ISO_9945.Glob.self",
                path: "Sources/Consumer Core/GlobImport.swift",
                expectation: .clean
            ),
            .init(
                id: "platform layer import iso 9945 incidental kernel text",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\n// ISO_9945.Kernel is not used here\nlet note = \"ISO_9945.Kernel\"\nlet name: ISO_9945.Utility.Name? = nil",
                path: "Sources/Consumer Core/IncidentalText.swift",
                expectation: .clean
            ),
            .init(
                id: "platform layer import iso 9945 kernel use",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet kernel: ISO_9945.Kernel? = nil",
                path: "Sources/Consumer Core/KernelUse.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import iso 9945 kernel use with whitespace",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet name: ISO_9945.Utility.Name? = nil\nlet kernel = ISO_9945\n    .Kernel.self",
                path: "Sources/Consumer Core/KernelWhitespace.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import iso 9945 kernel use with module selector",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet kernel: ISO_9945_Core::ISO_9945.Kernel? = nil",
                path: "Sources/Consumer Core/KernelSelector.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import iso 9945 utility import without use",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet value = 1",
                path: "Sources/Consumer Core/UnusedUtility.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import iso 9945 unrelated core member",
                source: "public import ISO_9945_Core\npublic import ISO_9945_Utility\nlet name: ISO_9945.Utility.Name? = nil\nlet other: ISO_9945.Errno? = nil",
                path: "Sources/Consumer Core/UnrelatedCore.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "platform layer import test boundary",
                source: "import POSIX_Kernel",
                path: "Tests/Consumer Tests/PolicyFixture.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !platformLayerImportIsInsidePlatformStackPackage(source.file.filePath) else {
                return []
            }
            guard !platformLayerImportIsOutsideMainTarget(source.file.filePath) else {
                return []
            }
            guard !platformLayerImportIsPackageManifest(source.file.filePath) else {
                return []
            }
            guard !platformLayerImportIsInsideHiddenDirectory(source.file.filePath) else {
                return []
            }
            let imports = PlatformLayerImportCollector(viewMode: .sourceAccurate)
            imports.walk(source.tree)
            let visitor = PlatformLayerImportVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                exempt: platformLayerImportSpecNamespaceExemption(
                    imports: imports.modules,
                    members: imports.namespaceMembers
                )
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let platformLayerImportMessage: Swift::String =
    "[platform layer import] [PLAT-ARCH-008]: non-platform-stack source "
    + "imports a platform-specific L2-spec or L3-policy module directly. "
    + "Consumers MUST import the L3-unifier surface (`import Kernel`, "
    + "`import IO`, etc.), never `Darwin_Kernel_Standard`, "
    + "`Linux_Kernel_Standard`, `Windows_32_Core`, `ISO_9945_Core`, "
    + "`Darwin_Kernel`, `Linux_Kernel`, `Windows_Kernel` or `POSIX_Kernel`. "
    + "The platform stack (L1 platform primitives, L2 spec, L3-policy, "
    + "L3-unifier, `swift-file-system`) exists precisely so the rest of the "
    + "ecosystem doesn't need these imports."

internal let platformLayerImportForbiddenModules: [Swift::String: Swift::String] = [
    "Darwin_Kernel_Standard": "swift-darwin-standard",
    "Linux_Kernel_Standard": "swift-linux-standard",
    "Windows_32_Core": "swift-windows-32",
    "ISO_9945_Core": "swift-iso-9945",
    "Darwin_Kernel": "swift-darwin",
    "Linux_Kernel": "swift-linux",
    "Windows_Kernel": "swift-windows",
    "POSIX_Kernel": "swift-posix",
]

internal let platformLayerImportPlatformStackPackages: Swift::Set<Swift::String> = [
    "swift-kernel",
    "swift-cpu",
    "swift-darwin",
    "swift-linux",
    "swift-windows",
    "swift-iso-9945",
    "swift-darwin-standard",
    "swift-linux-standard",
    "swift-windows-32",
    "swift-windows-standard",
    "swift-posix",
    "swift-darwin",
    "swift-linux",
    "swift-windows",
    "swift-kernel",
    "swift-strings",
    "swift-paths",
    "swift-ascii",
    "swift-systems",
    "swift-io",
    "swift-threads",
    "swift-environment",
    "swift-file-system",
]

private func platformLayerImportIsInsidePlatformStackPackage(
    _ filePath: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { component in
        platformLayerImportPlatformStackPackages.contains(Swift::String(component))
    }
}

private let platformLayerImportNonMainTargetRoots: [Swift::String] = [
    "Tests",
    "Experiments",
    "Examples",
]

private func platformLayerImportIsOutsideMainTarget(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count > 1 else { return false }
    return components.dropLast().contains { component in
        platformLayerImportNonMainTargetRoots.contains(Swift::String(component))
    }
}

private func platformLayerImportIsPackageManifest(_ filePath: Swift::String) -> Swift::Bool {
    guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
    else { return false }
    if filename == "Package.swift" { return true }
    return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}

private func platformLayerImportIsInsideHiddenDirectory(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    return components.contains { $0.hasPrefix(".") }
}

internal let platformLayerImportSpecNamespaceModules: [Swift::String: Swift::String] = [
    "Utility": "ISO_9945_Utility",
    "Glob": "ISO_9945_Glob",
]

internal func platformLayerImportSpecNamespaceExemption(
    imports: Swift::Set<Swift::String>,
    members: Swift::Set<Swift::String>
) -> Swift::Set<Swift::String> {
    let specUse =
        !members.isEmpty
        && members.allSatisfy { member in
            platformLayerImportSpecNamespaceModules[member].map { imports.contains($0) } ?? false
        }
    return specUse ? ["ISO_9945_Core"] : []
}

internal final class PlatformLayerImportCollector: SyntaxVisitor {
    var modules: Swift::Set<Swift::String> = []
    var namespaceMembers: Swift::Set<Swift::String> = []

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let pathText = node.path.trimmedDescription
        modules.insert(pathText.split(separator: ".").first.map(Swift::String.init) ?? pathText)
        return .skipChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        if node.baseType.as(IdentifierTypeSyntax.self)?.name.text == "ISO_9945" {
            namespaceMembers.insert(node.name.text)
        }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if node.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "ISO_9945" {
            namespaceMembers.insert(node.declName.baseName.text)
        }
        return .visitChildren
    }
}

internal func platformLayerImportForbiddenPackage(_ pathText: Swift::String) -> Swift::String? {
    let firstComponent = pathText.split(separator: ".").first.map(Swift::String.init) ?? pathText
    return platformLayerImportForbiddenModules[firstComponent]
}

internal final class PlatformLayerImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    let exempt: Swift::Set<Swift::String>
    private var reportedModules: Swift::Set<Swift::String> = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        exempt: Swift::Set<Swift::String>
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.exempt = exempt
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let pathText = node.path.trimmedDescription
        let firstComponent = pathText.split(separator: ".").first.map(Swift::String.init) ?? pathText
        guard platformLayerImportForbiddenModules[firstComponent] != nil,
            !exempt.contains(firstComponent)
        else {
            return .visitChildren
        }
        guard !reportedModules.contains(firstComponent) else {
            return .visitChildren
        }
        reportedModules.insert(firstComponent)
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
                identifier: "platform layer import",
                message: platformLayerImportMessage
            )
        )
        return .visitChildren
    }
}
