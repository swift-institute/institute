public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `sending return conditional sendable state` = Lint.Rule(
        id: "sending return conditional sendable state",
        default: .warning,
        controls: [
            .init(
                id: "sending return conditional sendable state disconnected",
                source: "public final class State<Base> { public func borrow() -> sending Base? { fatalError() } }\nextension State: @unchecked Sendable where Base: Sendable {}",
                path: "Sources/Memory Core/SendingConditionalState.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sending return conditional sendable state plain",
                source: "public final class State<Base> { public func borrow() -> Base? { fatalError() } }\nextension State: @unchecked Sendable where Base: Sendable {}",
                path: "Sources/Memory Core/PlainConditionalState.swift",
                expectation: .clean
            ),
            .init(
                id: "sending return conditional sendable state ungated",
                source: "public final class State<Base> { public func borrow() -> sending Base? { fatalError() } }",
                path: "Sources/Memory Core/UngatedSendingState.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemorySendingReturnConditionalSendableVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.resolvedMatches()
        }
    )
}

private let memorySendingReturnConditionalSendableMessage: Swift::String =
    "[sending return conditional sendable state]: this type's `@unchecked "
    + "Sendable` conformance is conditional on a generic parameter that "
    + "this return type mentions under a `sending` specifier. Region "
    + "isolation re-merges a plain return with `self`'s region at the call "
    + "site; a `sending`-typed return instead hands out a value "
    + "disconnected from `self` while this type stays reachable from the "
    + "original region — the exact race the conditional-Sendable gate "
    + "exists to prevent. Adding `sending` here is source-compatible with "
    + "every existing caller, so no test observes the regression; keep the "
    + "return type plain (per swift-property#7)."

internal final class MemorySendingReturnConditionalSendableVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    private var matches: [Diagnostic.Record] = []

    private var enclosingPath: [Swift::String] = []
    private var extensionPushCounts: [Swift::Int] = []

    private var genericParamsByPath: [Swift::String: Swift::Set<Swift::String>] = [:]
    private var gatedParamsByPath: [Swift::String: Swift::Set<Swift::String>] = [:]

    private struct Candidate {
        let path: Swift::String
        let position: AbsolutePosition
        let mentionedNames: Swift::Set<Swift::String>
    }
    private var candidates: [Candidate] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private var currentPath: Swift::String { enclosingPath.joined(separator: ".") }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        genericParamsByPath[currentPath] = sendingConditionalGenericParamNames(
            node.genericParameterClause
        )
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        genericParamsByPath[currentPath] = sendingConditionalGenericParamNames(
            node.genericParameterClause
        )
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        genericParamsByPath[currentPath] = sendingConditionalGenericParamNames(
            node.genericParameterClause
        )
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let pathComponents =
            sendingConditionalQualifiedPathComponents(node.extendedType) ?? ["<unknown>"]
        enclosingPath.append(contentsOf: pathComponents)
        extensionPushCounts.append(pathComponents.count)

        if sendingConditionalHasUncheckedSendable(node.inheritanceClause) {
            let gated = sendingConditionalGatedGenericParamNames(node.genericWhereClause)
            if !gated.isEmpty {
                gatedParamsByPath[currentPath, default: []].formUnion(gated)
            }
        }
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) {
        let count = extensionPushCounts.removeLast()
        enclosingPath.removeLast(count)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard sendingConditionalIsPublicOrPackageEffective(Syntax(node), modifiers: node.modifiers)
        else {
            return .visitChildren
        }
        if let returnType = node.signature.returnClause?.type {
            recordCandidateIfSending(returnType, at: returnType.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard sendingConditionalIsPublicOrPackageEffective(Syntax(node), modifiers: node.modifiers)
        else {
            return .visitChildren
        }
        let returnType = node.returnClause.type
        recordCandidateIfSending(returnType, at: returnType.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    private func recordCandidateIfSending(_ type: TypeSyntax, at position: AbsolutePosition) {
        guard let attributed = type.as(AttributedTypeSyntax.self),
            sendingConditionalHasSendingSpecifier(attributed)
        else { return }
        let mentioned = sendingConditionalMentionedIdentifierNames(attributed.baseType)
        guard !mentioned.isEmpty else { return }
        candidates.append(
            Candidate(path: currentPath, position: position, mentionedNames: mentioned)
        )
    }

    internal func resolvedMatches() -> [Diagnostic.Record] {
        for candidate in candidates {
            guard let gated = gatedParamsByPath[candidate.path], !gated.isEmpty else { continue }
            guard !candidate.mentionedNames.isDisjoint(with: gated) else { continue }
            let location = converter.location(for: candidate.position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "sending return conditional sendable state",
                    message: memorySendingReturnConditionalSendableMessage
                )
            )
        }
        return matches
    }
}

private func sendingConditionalGenericParamNames(
    _ clause: GenericParameterClauseSyntax?
)
    -> Swift::Set<Swift::String>
{
    guard let clause else { return [] }
    var names: Swift::Set<Swift::String> = []
    for parameter in clause.parameters {
        names.insert(Lint.Syntax.Identifier.unescaped(parameter.name.text))
    }
    return names
}

private func sendingConditionalQualifiedPathComponents(_ type: TypeSyntax) -> [Swift::String]? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(identifier.name.text)]
    }
    if let member = type.as(MemberTypeSyntax.self) {
        guard var base = sendingConditionalQualifiedPathComponents(member.baseType) else {
            return nil
        }
        base.append(Lint.Syntax.Identifier.unescaped(member.name.text))
        return base
    }
    return nil
}

private func sendingConditionalHasUncheckedSendable(
    _ clause: InheritanceClauseSyntax?
)
    -> Swift::Bool
{
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        guard let attributed = inherited.type.as(AttributedTypeSyntax.self) else { continue }
        guard sendingConditionalIsSendableLeaf(attributed.baseType) else { continue }
        for attribute in attributed.attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "unchecked" {
                return true
            }
        }
    }
    return false
}

private func sendingConditionalIsSendableLeaf(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "Sendable"
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(member.name.text) == "Sendable"
    }
    return false
}

private func sendingConditionalGatedGenericParamNames(
    _ clause: GenericWhereClauseSyntax?
)
    -> Swift::Set<Swift::String>
{
    guard let clause else { return [] }
    var names: Swift::Set<Swift::String> = []
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        guard sendingConditionalIsSendableLeaf(conformance.rightType) else { continue }
        names.insert(Lint.Syntax.Identifier.unescaped(conformance.leftType.trimmedDescription))
    }
    return names
}

private func sendingConditionalIsPublicOrPackageEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
) -> Swift::Bool {
    if sendingConditionalHasPublicOrPackage(modifiers) {
        return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return sendingConditionalHasPublicOrPackage(ext.modifiers)
        }
        current = candidate.parent
    }
    return false
}

private func sendingConditionalHasPublicOrPackage(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open), .keyword(.package): return true
        default: continue
        }
    }
    return false
}

private func sendingConditionalHasSendingSpecifier(_ type: AttributedTypeSyntax) -> Swift::Bool {
    for specifier in type.specifiers {
        guard let simple = specifier.as(SimpleTypeSpecifierSyntax.self) else { continue }
        if simple.specifier.tokenKind == .keyword(.sending) {
            return true
        }
    }
    return false
}

private func sendingConditionalMentionedIdentifierNames(
    _ type: TypeSyntax
)
    -> Swift::Set<Swift::String>
{
    var names: Swift::Set<Swift::String> = []
    func walk(_ type: TypeSyntax) {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            names.insert(Lint.Syntax.Identifier.unescaped(identifier.name.text))
            if let genericArgs = identifier.genericArgumentClause {
                for argument in genericArgs.arguments {
                    if let inner = argument.argument.as(TypeSyntax.self) { walk(inner) }
                }
            }
            return
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            walk(optional.wrappedType)
            return
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            walk(iuo.wrappedType)
            return
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            walk(array.element)
            return
        }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            walk(dictionary.key)
            walk(dictionary.value)
            return
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            walk(attributed.baseType)
            return
        }
        if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
            walk(someOrAny.constraint)
            return
        }
        if let member = type.as(MemberTypeSyntax.self) {
            walk(member.baseType)
            if let genericArgs = member.genericArgumentClause {
                for argument in genericArgs.arguments {
                    if let inner = argument.argument.as(TypeSyntax.self) { walk(inner) }
                }
            }
            return
        }
        if let tuple = type.as(TupleTypeSyntax.self) {
            for element in tuple.elements { walk(element.type) }
            return
        }
        if let function = type.as(FunctionTypeSyntax.self) {
            for parameter in function.parameters { walk(parameter.type) }
            walk(function.returnClause.type)
            return
        }
    }
    walk(type)
    return names
}
