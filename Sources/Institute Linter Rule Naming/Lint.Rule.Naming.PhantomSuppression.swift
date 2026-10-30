public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `phantom suppression` = Lint.Rule(
        id: "phantom suppression",
        default: .warning,
        controls: [
            .init(
                id: "phantom suppression copyable only",
                source: "extension Tagged where Underlying == Ordinal, Tag: ~Copyable { public var probe: Int { 0 } }",
                path: "Sources/Naming Core/CopyableOnly.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "phantom suppression maximal bound",
                source: "extension Tagged where Underlying == Ordinal, Tag: ~Copyable & ~Escapable { public var probe: Int { 0 } }",
                path: "Sources/Naming Core/MaximalBound.swift",
                expectation: .clean
            ),
            .init(
                id: "phantom suppression qualified maximal bound",
                source: "extension Tagged: Swift.Escapable where Tag: ~Copyable & ~Swift.Escapable, Underlying: Swift.Escapable & ~Copyable {}",
                path: "Sources/Naming Core/QualifiedMaximalBound.swift",
                expectation: .clean
            ),
            .init(
                id: "phantom suppression stored value",
                source: "extension Sequence { public func collect<Element: ~Copyable>(_ value: [Element]) {} }",
                path: "Sources/Naming Core/StoredValue.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingPhantomSuppressionVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingPhantomSuppressionMessage: Swift::String =
    "[phantom suppression] [API-NAME-010b]: phantom generic parameter (a pure "
    + "Tagged/Index/Property discriminator, never stored) is under-suppressed — "
    + "bind it `~Copyable & ~Escapable`, not `~Copyable`-only or bare. A marker "
    + "requirement on a phantom is vacuous over-constraint (Reynolds parametricity)."

internal final class NamingPhantomSuppressionVisitor: SyntaxVisitor {
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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let wrapper = phantomWrapperBaseName(node.extendedType) else { return .visitChildren }
        guard let whereClause = node.genericWhereClause else { return .visitChildren }
        for requirement in whereClause.requirements {
            guard case .conformanceRequirement(let conformance) = requirement.requirement else {
                continue
            }
            guard let left = conformance.leftType.as(IdentifierTypeSyntax.self) else { continue }
            guard left.name.text == phantomParameterName(ofWrapper: wrapper) else { continue }
            if constraintIsCopyableOnly(conformance.rightType) {
                emit(at: conformance.rightType.positionAfterSkippingLeadingTrivia)
            }
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkGenericParameters(
            node.genericParameterClause,
            whereClause: node.genericWhereClause,
            in: Syntax(node)
        )
        return .visitChildren
    }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkGenericParameters(
            node.genericParameterClause,
            whereClause: node.genericWhereClause,
            in: Syntax(node)
        )
        return .visitChildren
    }
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        checkGenericParameters(
            node.genericParameterClause,
            whereClause: node.genericWhereClause,
            in: Syntax(node)
        )
        return .visitChildren
    }
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        checkGenericParameters(
            node.genericParameterClause,
            whereClause: node.genericWhereClause,
            in: Syntax(node)
        )
        return .visitChildren
    }

    private func checkGenericParameters(
        _ clause: GenericParameterClauseSyntax?,
        whereClause: GenericWhereClauseSyntax?,
        in decl: Syntax
    ) {
        guard let clause else { return }
        let body = decl.trimmedDescription
        for parameter in clause.parameters {
            let name = parameter.name.text
            guard let inherited = parameter.inheritedType, constraintIsCopyableOnly(inherited)
            else {
                continue
            }
            guard usedAsPhantomDiscriminator(name, in: body), !usedAsStoredValue(name, in: body),
                !usedAsWhereClauseContainerBinding(name, in: whereClause),
                !usedAtStructurallyEscapablePosition(name, in: body)
            else {
                continue
            }
            emit(at: parameter.name.positionAfterSkippingLeadingTrivia)
        }
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
                identifier: "phantom suppression",
                message: namingPhantomSuppressionMessage
            )
        )
    }
}

private func phantomParameterName(ofWrapper leaf: Swift::String) -> Swift::String {
    leaf == "Index" ? "Element" : "Tag"
}

private func phantomWrapperBaseName(_ type: TypeSyntax) -> Swift::String? {
    let leaf: Swift::String? =
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            identifier.name.text
        } else if let member = type.as(MemberTypeSyntax.self) {
            member.name.text
        } else {
            nil
        }
    guard let leaf, leaf == "Tagged" || leaf == "Index" || leaf == "Property" else { return nil }
    return leaf
}

private func constraintIsCopyableOnly(_ type: TypeSyntax) -> Swift::Bool {
    if let suppressed = type.as(SuppressedTypeSyntax.self) {
        return suppressedIsCopyable(suppressed)
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        var sawCopyable = false
        var sawEscapable = false
        for element in composition.elements {
            if let suppressed = element.type.as(SuppressedTypeSyntax.self) {
                if suppressedIsCopyable(suppressed) { sawCopyable = true }
                if suppressedLeaf(suppressed) == "Escapable" { sawEscapable = true }
            }
        }
        return sawCopyable && !sawEscapable
    }
    return false
}

private func suppressedIsCopyable(_ suppressed: SuppressedTypeSyntax) -> Swift::Bool {
    suppressedLeaf(suppressed) == "Copyable"
}

private func suppressedLeaf(_ suppressed: SuppressedTypeSyntax) -> Swift::String? {
    suppressed.type.as(IdentifierTypeSyntax.self)?.name.text
        ?? suppressed.type.as(MemberTypeSyntax.self)?.name.text
}

private func usedAsPhantomDiscriminator(_ name: Swift::String, in body: Swift::String) -> Swift::Bool {
    for wrapper in ["Tagged<", "Index<", "Property<"] {
        if body.contains(wrapper + name + ",") || body.contains(wrapper + name + ">") {
            return true
        }
    }
    return false
}

private func usedAsStoredValue(_ name: Swift::String, in body: Swift::String) -> Swift::Bool {
    for marker in [
        "[" + name + "]", "-> " + name, ": " + name + ")", ": " + name + " ",
        ": " + name + ",", ": " + name + "\n", name + "?",
        "consuming " + name, "borrowing " + name, "inout " + name,
    ] where body.contains(marker) {
        return true
    }
    return false
}

private let namingPhantomEscapableConstrainedGenericTypes: [Swift::String] = [
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "AutoreleasingUnsafeMutablePointer",
    "ManagedBuffer",
    "ManagedBufferPointer",
]

private func usedAtStructurallyEscapablePosition(
    _ name: Swift::String,
    in body: Swift::String
) -> Swift::Bool {
    for type in namingPhantomEscapableConstrainedGenericTypes {
        if body.contains(type + "<" + name + ">") || body.contains(type + "<" + name + ",") {
            return true
        }
    }
    return false
}

private func usedAsWhereClauseContainerBinding(
    _ name: Swift::String,
    in whereClause: GenericWhereClauseSyntax?
) -> Swift::Bool {
    guard let whereClause else { return false }
    for requirement in whereClause.requirements {
        guard case .sameTypeRequirement(let sameType) = requirement.requirement else { continue }
        if let leftType = sameType.leftType.as(TypeSyntax.self),
            usedAsGenericArgument(name, in: leftType)
        {
            return true
        }
        if let rightType = sameType.rightType.as(TypeSyntax.self),
            usedAsGenericArgument(name, in: rightType)
        {
            return true
        }
    }
    return false
}

private func usedAsGenericArgument(_ name: Swift::String, in type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return genericArgumentsBind(name, identifier.genericArgumentClause)
    }
    if let member = type.as(MemberTypeSyntax.self) {
        if genericArgumentsBind(name, member.genericArgumentClause) { return true }
        return usedAsGenericArgument(name, in: member.baseType)
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return usedAsGenericArgument(name, in: optional.wrappedType)
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return usedAsGenericArgument(name, in: attributed.baseType)
    }
    return false
}

private func genericArgumentsBind(
    _ name: Swift::String,
    _ clause: GenericArgumentClauseSyntax?
) -> Swift::Bool {
    guard let clause else { return false }
    for argument in clause.arguments {
        guard let argumentType = argument.argument.as(TypeSyntax.self) else { continue }
        if let identifier = argumentType.as(IdentifierTypeSyntax.self), identifier.name.text == name {
            return true
        }
        if usedAsGenericArgument(name, in: argumentType) { return true }
    }
    return false
}
