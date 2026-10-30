public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `wrapper backing exposed` = Lint.Rule(
        id: "wrapper backing exposed",
        default: .warning,
        controls: [
            .init(
                id: "wrapper backing exposed protocol requirement witness",
                source: "public protocol _OptionalProtocol<Wrapped> { associatedtype Wrapped; var _wrapped: Wrapped? { get } }\n"
                    + "extension Optional: _OptionalProtocol { public var _wrapped: Wrapped? { self } }",
                path: "Sources/Structure Core/Optional.swift",
                expectation: .clean
            ),
            .init(
                id: "wrapper backing exposed public backing without a requirement",
                source: "public struct Box { public var _backing: Int }",
                path: "Sources/Structure Core/Box.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "wrapper backing exposed internal backing",
                source: "struct Wrapper { var _backing: Int }",
                path: "Sources/Structure Core/Wrapper.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "wrapper backing exposed private backing",
                source: "struct Wrapper { private var _backing: Int }",
                path: "Sources/Structure Core/Wrapper.swift",
                expectation: .clean
            ),
            .init(
                id: "wrapper backing exposed file scope",
                source: "var _backing: Int = 0",
                path: "Sources/Structure Core/Backing.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = StructureWrapperBackingExposedVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                index: source.index
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let structureWrapperBackingExposedMessage: Swift::String =
    "[wrapper backing exposed] [API-IMPL-011]: wrapper backing property "
    + "(`_backing` / `_wrapped` / `_underlying`) is exposed at non-private "
    + "visibility — consumers will reach through (`wrapper._backing.run { … }`) "
    + "for any operation the wrapper itself doesn't surface, and the wrapper "
    + "looks fake. Make the property `private` (or `fileprivate`), and own the "
    + "primary operation on the wrapper directly. `@usableFromInline` is exempt."

internal let structureWrapperBackingExposedTrackedNames: Swift::Set<Swift::String> = [
    "_backing",
    "_wrapped",
    "_underlying",
]

internal func structureWrapperBackingExposedHasPrivateOrFilePrivate(
    _ modifiers: DeclModifierListSyntax
) -> Swift::Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.private), .keyword(.fileprivate):
            if modifier.detail == nil {
                return true
            }

        default:
            continue
        }
    }
    return false
}

internal func structureWrapperBackingExposedHasUsableFromInline(
    _ attributes: AttributeListSyntax
)
    -> Swift::Bool
{
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "usableFromInline" {
            return true
        }
    }
    return false
}

internal final class StructureWrapperBackingExposedVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var typeDepth: Swift::Int = 0
    let index: Lint.Source.Index

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        index: Lint.Source.Index
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.index = index
        super.init(viewMode: .sourceAccurate)
    }

    private func witnessesRequirement(_ name: Swift::String, _ node: Syntax) -> Swift::Bool {
        var current = node.parent
        while let candidate = current {
            let owner: Swift::String? =
                if let decl = candidate.as(ExtensionDeclSyntax.self) {
                    decl.extendedType.trimmedDescription
                } else if let decl = candidate.as(StructDeclSyntax.self) {
                    decl.name.text
                } else if let decl = candidate.as(EnumDeclSyntax.self) {
                    decl.name.text
                } else if let decl = candidate.as(ClassDeclSyntax.self) {
                    decl.name.text
                } else {
                    nil
                }
            if let owner { return index.witnessesRequirement(named: name, on: owner) }
            current = candidate.parent
        }
        return false
    }

    override func visit(_: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { typeDepth -= 1 }

    override func visit(_: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { typeDepth -= 1 }

    override func visit(_: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { typeDepth -= 1 }

    override func visit(_: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { typeDepth -= 1 }

    override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { typeDepth -= 1 }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard typeDepth > 0 else { return .visitChildren }
        if structureWrapperBackingExposedHasPrivateOrFilePrivate(node.modifiers) {
            return .visitChildren
        }
        if structureWrapperBackingExposedHasUsableFromInline(node.attributes) {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            guard
                structureWrapperBackingExposedTrackedNames.contains(
                    identifier.identifier.text
                )
            else { continue }
            guard !witnessesRequirement(identifier.identifier.text, Syntax(node)) else { continue }
            let location = converter.location(
                for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia
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
                    identifier: "wrapper backing exposed",
                    message: structureWrapperBackingExposedMessage
                )
            )
            break
        }
        return .visitChildren
    }
}
