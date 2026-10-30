public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `ad hoc box class` = Lint.Rule(
        id: "ad hoc box class",
        default: .warning,
        controls: [
            .init(
                id: "ad hoc box class positive",
                source: "final class Storage {}",
                path: "Controls/AdHocBoxClass/Positive.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "ad hoc box class unrelated name",
                source: "final class Inventory {}",
                path: "Controls/AdHocBoxClass/UnrelatedName.swift",
                expectation: .clean
            ),
            .init(
                id: "ad hoc box class inherited exemption",
                source: "final class Storage: ManagedBuffer<Int, Int> {}",
                path: "Controls/AdHocBoxClass/InheritedExemption.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingBoxClassVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingBoxClassMessage: Swift::String =
    "[ad hoc box class] [IMPL-107]: ad-hoc `_Box` / `_Storage` reference "
    + "wrapper duplicates ecosystem primitives. Prefer `Reference<T>` "
    + "(shared mutable indirection) or `Owned<T>` (unique-owner indirection) "
    + "from `swift-ownership` so the wrapper's ownership story "
    + "is checked by the type system, not ad-hoc."

private let namingBoxClassFlaggedNames: Swift::Set<Swift::String> = [
    "Box", "Storage", "Wrap", "Wrapper", "Cell",
]

private func namingBoxClassIsFlaggedName(_ name: Swift::String) -> Swift::Bool {
    var trimmed = name
    if trimmed.hasPrefix("_") {
        trimmed.removeFirst()
    }
    return namingBoxClassFlaggedNames.contains(trimmed)
}

internal final class NamingBoxClassVisitor: SyntaxVisitor {
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

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.inheritanceClause != nil {
            return .visitChildren
        }
        let name = node.name.text
        if !namingBoxClassIsFlaggedName(name) {
            return .visitChildren
        }
        if namingBoxClassIsCanonicalCoWBacking(node) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.name.positionAfterSkippingLeadingTrivia
        )
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "ad hoc box class",
                message: namingBoxClassMessage
            )
        )
        return .visitChildren
    }
}

private func namingBoxClassIsCanonicalCoWBacking(_ node: ClassDeclSyntax) -> Swift::Bool {
    var isFinal = false
    for modifier in node.modifiers {
        if modifier.name.tokenKind == .keyword(.final) {
            isFinal = true
            break
        }
    }
    if !isFinal { return false }
    for element in node.attributes {
        if let attribute = element.as(AttributeSyntax.self) {
            let attributeName = attribute.attributeName.trimmedDescription
            if attributeName == "usableFromInline" {
                return true
            }
        }
    }
    return false
}
