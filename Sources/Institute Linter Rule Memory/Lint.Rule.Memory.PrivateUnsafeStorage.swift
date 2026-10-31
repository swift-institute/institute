public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `unsafe storage visibility` = Lint.Rule(
        id: "unsafe storage visibility",
        default: .warning,
        controls: [
            .init(
                id: "unsafe storage visibility public pointer",
                source: """
                    struct Buffer {
                      public let storage: UnsafeMutablePointer<UInt8>
                    }
                    """,
                path: "Controls/UnsafeStorageVisibility.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryPrivateUnsafeStorageVisitor(
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
internal let `unsafe storage visibility message`: Swift::String =
    "[unsafe storage visibility] [MEM-SAFE-023]: public stored properties of unsafe "
    + "pointer types MUST be `private` / `internal`, or annotated `@unsafe` to "
    + "signal a deliberate escape hatch. Public pointer storage on an Escapable "
    + "wrapper leaks dangling-pointer risk past the wrapper's lifetime. Prefer "
    + "exposing a `Span` view; reserve `@unsafe` for explicit escape hatches."

@usableFromInline
internal let `unsafe pointer types`: Swift::Set<Swift::String> = [
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "UnsafeRawBufferPointer",
    "UnsafeMutableRawBufferPointer",
]

internal func isUnsafePointerType(_ type: TypeSyntax) -> Bool {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) {
        current = optional.wrappedType
    }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = iuo.wrappedType
    }
    while let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return `unsafe pointer types`.contains(identifier.name.text)
    }
    if let member = current.as(MemberTypeSyntax.self) {
        return `unsafe pointer types`.contains(member.name.text)
    }
    return false
}

internal final class MemoryPrivateUnsafeStorageVisitor: SyntaxVisitor {
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

    private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return true

            default:
                continue
            }
        }
        return false
    }

    private func hasUnsafeAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "unsafe" {
                return true
            }
        }
        return false
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicModifier(node.modifiers) else {
            return .visitChildren
        }
        guard !hasUnsafeAttribute(node.attributes) else {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let typeAnnotation = binding.typeAnnotation else { continue }
            if isUnsafePointerType(typeAnnotation.type) {
                let location = converter.location(
                    for: binding.pattern.positionAfterSkippingLeadingTrivia
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
                        identifier: "unsafe storage visibility",
                        message: `unsafe storage visibility message`
                    )
                )
            }
        }
        return .visitChildren
    }
}
