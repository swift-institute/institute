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
                id: "architecture foundation type appkit class in an appkit file",
                source: "import AppKit\n\nfinal class Bridge: NSView {\n    var window: NSWindow?\n}",
                path: "Sources/Architecture AppKit/Bridge.swift",
                expectation: .clean
            ),
            .init(
                id: "architecture foundation type foundation class without a ui framework",
                source: "import Foundation\n\npublic var count: NSNumber",
                path: "Sources/Architecture Core/Count.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture foundation type qualified use in an appkit file",
                source: "import AppKit\n\npublic var payload: Foundation.Data",
                path: "Sources/Architecture AppKit/Payload.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture foundation type a framework's required delegate base",
                source: "import Sparkle\n\nfileprivate final class Bridge: NSObject, SPUUpdaterDelegate {}",
                path: "Sources/Architecture Platform/Bridge.swift",
                expectation: .clean
            ),
            .init(
                id: "architecture foundation type foundation inside a required delegate",
                source: "fileprivate final class Bridge: NSObject, SPUUpdaterDelegate {\n    var count: NSNumber?\n}",
                path: "Sources/Architecture Platform/Bridge.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture foundation type public NSObject subclass",
                source: "public final class Bridge: NSObject, SPUUpdaterDelegate {}",
                path: "Sources/Architecture Platform/Bridge.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture foundation type NSObject subclass conforming to nothing",
                source: "fileprivate final class Bridge: NSObject {}",
                path: "Sources/Architecture Platform/Bridge.swift",
                expectation: .findings(1)
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
                converter: source.converter,
                classes: architectureFoundationTypeImportsInterfaceFramework(source.tree) ? .interface : .foundation
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

/// The frameworks whose own classes carry the `NS` or `UI` prefix: in a file that imports one, an `NS` name is
/// judged that framework's, while a module-qualified Foundation type is still flagged.
private let architectureFoundationTypeInterfaceFrameworks: Swift::Set<Swift::String> = ["AppKit", "UIKit"]

private func architectureFoundationTypeImportsInterfaceFramework(_ tree: SourceFileSyntax) -> Swift::Bool {
    tree.statements.contains { statement in
        guard let declaration = statement.item.as(ImportDeclSyntax.self), let module = declaration.path.first?.name.text
        else { return false }
        return architectureFoundationTypeInterfaceFrameworks.contains(module)
    }
}

/// Whether `node` is `NSObject` as the superclass of a `private` or `fileprivate` class that also conforms to a
/// protocol: the base an Objective-C framework requires of its delegate (Sparkle's `SPUUpdaterDelegate`), which no
/// Institute type can replace. Foundation types inside that class are still findings (#247).
private func architectureFoundationTypeIsRequiredDelegateBase(_ node: IdentifierTypeSyntax) -> Swift::Bool {
    guard node.name.text == "NSObject", node.genericArgumentClause == nil,
        let inherited = node.parent?.as(InheritedTypeSyntax.self),
        let list = inherited.parent?.as(InheritedTypeListSyntax.self),
        list.first?.id == inherited.id, list.count > 1,
        let declaration = list.parent?.parent?.as(ClassDeclSyntax.self)
    else { return false }
    return declaration.modifiers.contains { modifier in
        modifier.name.tokenKind == .keyword(.private) || modifier.name.tokenKind == .keyword(.fileprivate)
    }
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
    let classes: Classes
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter, classes: Classes) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.classes = classes
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
        if classes == .foundation, architectureFoundationTypeIsFoundationClassName(node.name.text),
            !architectureFoundationTypeIsRequiredDelegateBase(node)
        {
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

extension ArchitectureFoundationTypeVisitor {
    /// Whose classes an `NS` name in the file names.
    enum Classes {
        /// Foundation's: the file imports no interface framework.
        case foundation
        /// AppKit's or UIKit's: the file imports one.
        case interface
    }
}
