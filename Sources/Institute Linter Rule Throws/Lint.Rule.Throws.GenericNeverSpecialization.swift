public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `generic throws missing never` = Lint.Rule(
        id: "generic throws missing never",
        default: .warning,
        controls: [
            .init(
                id: "generic throws missing never public generic failure",
                source: "public struct Parser<Sink> { "
                    + "public func parse() throws(Sink.Failure) {} }",
                path: "Sources/Throws Consumer/GenericFailure.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "generic throws missing never concrete failure",
                source: "public struct Parser<Sink> { "
                    + "public func parse() throws(Parse.Error) {} }",
                path: "Sources/Throws Consumer/ConcreteFailure.swift",
                expectation: .clean
            ),
            .init(
                id: "generic throws missing never inlinable boundary",
                source: "public struct Parser<Sink> { "
                    + "@inlinable public func parse() throws(Sink.Failure) {} }",
                path: "Sources/Throws Consumer/InlinableGenericFailure.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsGenericNeverSpecializationVisitor(
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
internal let throwsGenericNeverSpecializationMessage: Swift::String =
    "[generic throws missing never] [IMPL-042]: public "
    + "generic API throws a generic-parameter-typed error. The rule fires "
    + "as a REVIEW PROMPT — per [IMPL-042]'s 'When to apply' criteria the "
    + "duplication is justified only when the callback is invoked in a "
    + "tight loop / per-token, benchmarks attribute measurable cost, and "
    + "the body is stable for duplication. Dispositions: (a) add a non-"
    + "throwing `where <G>.<Sub> == Never` companion with a duplicated body "
    + "in the same extension — the recognizer detects in-extension "
    + "companions and won't re-fire; or (b) per-line suppress with "
    + "`// REASON:` if the 'When to apply' criteria don't hold. The rule "
    + "does not fire on `@inlinable` / `@_alwaysEmitIntoClient` "
    + "declarations because the compiler can specialize at consumer call "
    + "sites without a duplicated body."

private func gnsIsPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open): return true
        default: continue
        }
    }
    return false
}

private func gnsIsPublicOrOpenEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
) -> Swift::Bool {
    if gnsIsPublicOrOpen(modifiers) {
        return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return gnsIsPublicOrOpen(ext.modifiers)
        }
        current = candidate.parent
    }
    return false
}

private func gnsCollectGenericParamNames(
    _ clause: GenericParameterClauseSyntax?
)
    -> Swift::Set<Swift::String>
{
    guard let clause else { return [] }
    var names: Swift::Set<Swift::String> = []
    for parameter in clause.parameters { names.insert(parameter.name.text) }
    return names
}

private func gnsGenericFailureTypePosition(
    in clause: ThrowsClauseSyntax?,
    availableGenerics: Swift::Set<Swift::String>
) -> AbsolutePosition? {
    guard let clause, let type = clause.type else { return nil }
    guard let member = type.as(MemberTypeSyntax.self) else { return nil }
    guard let base = member.baseType.as(IdentifierTypeSyntax.self) else { return nil }
    guard availableGenerics.contains(base.name.text) else { return nil }
    return member.positionAfterSkippingLeadingTrivia
}

private func gnsCollectExtendedGenericNames(_ type: TypeSyntax) -> Swift::Set<Swift::String> {
    _ = type
    return []
}

private func gnsIsInlinable(_ attributes: AttributeListSyntax) -> Swift::Bool {
    for element in attributes {
        guard let attr = element.as(AttributeSyntax.self) else { continue }
        guard let ident = attr.attributeName.as(IdentifierTypeSyntax.self) else { continue }
        switch ident.name.text {
        case "inlinable", "_alwaysEmitIntoClient": return true
        default: continue
        }
    }
    return false
}

private func gnsCollectNeverCompanionNames(
    in extensionDecl: ExtensionDeclSyntax
) -> Swift::Set<Swift::String> {
    var names: Swift::Set<Swift::String> = []
    for memberItem in extensionDecl.memberBlock.members {
        if let funcDecl = memberItem.decl.as(FunctionDeclSyntax.self),
            gnsHasNeverFailureWhereClause(funcDecl.genericWhereClause)
        {
            names.insert(funcDecl.name.text)
        }
        if let initDecl = memberItem.decl.as(InitializerDeclSyntax.self),
            gnsHasNeverFailureWhereClause(initDecl.genericWhereClause)
        {
            names.insert("init")
        }
    }
    return names
}

private func gnsHasNeverFailureWhereClause(_ clause: GenericWhereClauseSyntax?) -> Swift::Bool {
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else {
            continue
        }
        let left = sameType.leftType.trimmedDescription
        let right = sameType.rightType.trimmedDescription
        if left == "Never" || left == "Swift.Never" { return true }
        if right == "Never" || right == "Swift.Never" { return true }
    }
    return false
}

internal final class ThrowsGenericNeverSpecializationVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var genericsStack: [Swift::Set<Swift::String>] = []
    var companionsStack: [Swift::Set<Swift::String>] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func emit(at position: AbsolutePosition) {
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
                identifier: "generic throws missing never",
                message: throwsGenericNeverSpecializationMessage
            )
        )
    }

    private func currentAvailable(
        _ funcGenerics: Swift::Set<Swift::String>
    ) -> Swift::Set<Swift::String> {
        var result: Swift::Set<Swift::String> = funcGenerics
        for set in genericsStack { result.formUnion(set) }
        return result
    }

    private func hasCompanion(_ baseName: Swift::String) -> Swift::Bool {
        for set in companionsStack {
            if set.contains(baseName) { return true }
        }
        return false
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectExtendedGenericNames(node.extendedType))
        companionsStack.append(gnsCollectNeverCompanionNames(in: node))
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) {
        genericsStack.removeLast()
        companionsStack.removeLast()
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard gnsIsPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        if gnsIsInlinable(node.attributes) { return .visitChildren }
        if hasCompanion(node.name.text) { return .visitChildren }
        let funcGenerics = gnsCollectGenericParamNames(node.genericParameterClause)
        let available = currentAvailable(funcGenerics)
        if let position = gnsGenericFailureTypePosition(
            in: node.signature.effectSpecifiers?.throwsClause,
            availableGenerics: available
        ) {
            emit(at: position)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard gnsIsPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        if gnsIsInlinable(node.attributes) { return .visitChildren }
        if hasCompanion("init") { return .visitChildren }
        let funcGenerics = gnsCollectGenericParamNames(node.genericParameterClause)
        let available = currentAvailable(funcGenerics)
        if let position = gnsGenericFailureTypePosition(
            in: node.signature.effectSpecifiers?.throwsClause,
            availableGenerics: available
        ) {
            emit(at: position)
        }
        return .visitChildren
    }
}
