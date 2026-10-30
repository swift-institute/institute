public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `optionset shell pattern` = Lint.Rule(
        id: "optionset shell pattern",
        default: .warning,
        controls: [
            .init(
                id: "optionset shell pattern value in shell",
                source: "struct Options: OptionSet { let rawValue: Int; "
                    + "static let create = Self(rawValue: 1) }",
                path: "Sources/Platform Core/OptionsShell.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "optionset shell pattern value in extension",
                source: "struct Options: OptionSet { let rawValue: Int }; "
                    + "extension Options { static let create = Self(rawValue: 1) }",
                path: "Sources/Platform Core/OptionsValues.swift",
                expectation: .clean
            ),
            .init(
                id: "optionset shell pattern non-optionset",
                source: "struct Holder { let rawValue: Int; static let create = Self(rawValue: 1) }",
                path: "Sources/Platform Core/Holder.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformOptionSetShellVisitor(
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
internal let platformOptionSetShellMessage: Swift::String =
    "[optionset shell pattern] [PLAT-ARCH-013]: OptionSet type body "
    + "contains a `static let X = Self(rawValue: …)` platform-constant "
    + "declaration. Move platform constants to an extension to preserve "
    + "the shell + values shape: L1 (or shared) declares the empty "
    + "shell, L2 / per-platform packages add constants via extension. "
    + "Authors get cross-platform layering for free; consumers see the "
    + "shell once, the platform vocabulary at each layer."

internal func platformOptionSetShellConformsToOptionSet(
    _ inheritanceClause: InheritanceClauseSyntax?
) -> Swift::Bool {
    guard let inheritanceClause else { return false }
    for inherited in inheritanceClause.inheritedTypes {
        if let identifier = inherited.type.as(IdentifierTypeSyntax.self),
            identifier.name.text == "OptionSet"
        {
            return true
        }
        if let member = inherited.type.as(MemberTypeSyntax.self),
            member.name.text == "OptionSet",
            let base = member.baseType.as(IdentifierTypeSyntax.self),
            base.name.text == "Swift"
        {
            return true
        }
    }
    return false
}

internal func platformOptionSetShellIsStaticDecl(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    for modifier in modifiers {
        if case .keyword(.static) = modifier.name.tokenKind {
            return true
        }
    }
    return false
}

internal func platformOptionSetShellIsSelfRawValueInit(
    _ initializer: InitializerClauseSyntax?,
    typeName: Swift::String
) -> Swift::Bool {
    guard let initializer else { return false }
    guard let call = initializer.value.as(FunctionCallExprSyntax.self) else {
        return false
    }
    let hasRawValueLabel = call.arguments.contains { $0.label?.text == "rawValue" }
    guard hasRawValueLabel else { return false }
    if let callee = call.calledExpression.as(DeclReferenceExprSyntax.self) {
        return callee.baseName.text == "Self" || callee.baseName.text == typeName
    }
    if let member = call.calledExpression.as(MemberAccessExprSyntax.self),
        member.declName.baseName.text == "init"
    {
        guard let base = member.base else { return true }
        if let baseRef = base.as(DeclReferenceExprSyntax.self) {
            return baseRef.baseName.text == "Self" || baseRef.baseName.text == typeName
        }
        return false
    }
    return false
}

internal final class PlatformOptionSetShellVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard platformOptionSetShellConformsToOptionSet(node.inheritanceClause) else {
            return .visitChildren
        }
        let typeName = Lint.Syntax.Identifier.unescaped(node.name.text)
        for member in Lint.Syntax.Conditional.members(node.memberBlock) {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard platformOptionSetShellIsStaticDecl(variable.modifiers) else {
                continue
            }
            for binding in variable.bindings {
                if platformOptionSetShellIsSelfRawValueInit(binding.initializer, typeName: typeName) {
                    let location = converter.location(
                        for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia
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
                            identifier: "optionset shell pattern",
                            message: platformOptionSetShellMessage
                        )
                    )
                    break
                }
            }
        }
        return .visitChildren
    }
}
