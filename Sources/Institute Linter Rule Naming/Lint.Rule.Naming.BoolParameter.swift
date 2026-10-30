public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `bool public parameter` = Lint.Rule(
        id: "bool public parameter",
        default: .warning,
        controls: [
            .init(
                id: "bool public parameter public bool",
                source: "public func open(create: Bool) {}",
                path: "Sources/Naming Core/PublicBool.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bool public parameter internal bool",
                source: "func open(create: Bool) {}",
                path: "Sources/Naming Core/InternalBool.swift",
                expectation: .clean
            ),
            .init(
                id: "bool public parameter enum alternative",
                source: "public enum Mode { case create }; public func open(mode: Mode) {}",
                path: "Sources/Naming Core/EnumAlternative.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingBoolParameterVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingBoolParameterMessage: Swift::String =
    "[bool public parameter] [API-IMPL-003]: public function/initializer "
    + "signature has a `Bool` parameter. Use an enum (or named-options "
    + "struct) so additional states can be added without an API break "
    + "and so call sites read as intent (`mode: .strict`) rather than "
    + "magic flags (`strict: true`). `package`-scope and non-public "
    + "declarations are exempt; closure-typed parameters with internal "
    + "Bool arguments are exempt. Memberwise initializers of wire-schema "
    + "types (`Codable`/`Decodable`/`Encodable` conformers whose Bool "
    + "field mirrors a remote provider's schema) and of `Options` "
    + "named-options structs (the rule's own prescribed remedy) are "
    + "exempt per the #16 Option C ledger, Entry II.3."

private func namingBoolParameterIsBoolType(_ type: TypeSyntax) -> Bool {
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
    while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
        let element = tuple.elements.first
    {
        current = element.type
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return identifier.name.text == "Bool"
    }
    if let member = current.as(MemberTypeSyntax.self) {
        if member.name.text == "Bool",
            let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
            baseIdentifier.name.text == "Swift"
        {
            return true
        }
    }
    return false
}

internal final class NamingBoolParameterVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Naming.hasPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        if Naming.Build.methods.contains(node.name.text),
            Naming.isInsideExtensionPattern(Syntax(node))
        {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Naming.hasPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        let parameters = node.signature.parameterClause.parameters
        if parameters.count == 1,
            let only = parameters.first,
            only.firstName.tokenKind == .wildcard,
            namingBoolParameterIsBoolType(only.type)
        {
            return .visitChildren
        }
        let wireSchema = namingBoolParameterHasWireSchemaConformance(Syntax(node))
        let optionsStruct = namingBoolParameterEnclosingTypeName(Syntax(node)) == "Options"
        for parameter in parameters {
            guard namingBoolParameterIsBoolType(parameter.type) else { continue }
            if wireSchema || optionsStruct {
                let internalName = parameter.secondName?.text ?? parameter.firstName.text
                if namingBoolParameterAssignsSelf(node.body, parameter: internalName) {
                    continue
                }
            }
            emit(parameter)
        }
        return .visitChildren
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        for parameter in parameters {
            guard namingBoolParameterIsBoolType(parameter.type) else {
                continue
            }
            emit(parameter)
        }
    }

    private func emit(_ parameter: FunctionParameterSyntax) {
        let location = converter.location(
            for: parameter.firstName.positionAfterSkippingLeadingTrivia
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
                identifier: "bool public parameter",
                message: namingBoolParameterMessage
            )
        )
    }
}

private func namingBoolParameterHasWireSchemaConformance(_ node: Syntax) -> Bool {
    let wireSchemaLeaves: Swift::Set<Swift::String> = ["Codable", "Decodable", "Encodable"]
    for leaf in Naming.conformances(node) where wireSchemaLeaves.contains(leaf) {
        return true
    }
    return false
}

private func namingBoolParameterEnclosingTypeName(_ node: Syntax) -> Swift::String? {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let decl = candidate.as(StructDeclSyntax.self) { return decl.name.text }
        if let decl = candidate.as(ClassDeclSyntax.self) { return decl.name.text }
        if let decl = candidate.as(EnumDeclSyntax.self) { return decl.name.text }
        if let decl = candidate.as(ActorDeclSyntax.self) { return decl.name.text }
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            let path = ext.extendedType.trimmedDescription
            if let leaf = path.split(separator: ".").last { return Swift::String(leaf) }
            return path
        }
        current = candidate.parent
    }
    return nil
}

private func namingBoolParameterAssignsSelf(
    _ body: CodeBlockSyntax?,
    parameter name: Swift::String
) -> Bool {
    guard let body else { return false }
    for item in body.statements {
        if let sequence = item.item.as(SequenceExprSyntax.self) {
            let elements = Array(sequence.elements)
            if elements.count == 3,
                elements[1].is(AssignmentExprSyntax.self),
                namingBoolParameterIsSelfMember(elements[0], named: name),
                namingBoolParameterIsReference(elements[2], named: name)
            {
                return true
            }
        }
        if let infix = item.item.as(InfixOperatorExprSyntax.self),
            infix.operator.is(AssignmentExprSyntax.self),
            namingBoolParameterIsSelfMember(infix.leftOperand, named: name),
            namingBoolParameterIsReference(infix.rightOperand, named: name)
        {
            return true
        }
    }
    return false
}

private func namingBoolParameterIsSelfMember(_ expr: ExprSyntax, named name: Swift::String) -> Bool {
    guard let member = expr.as(MemberAccessExprSyntax.self),
        member.declName.baseName.text == name,
        let base = member.base?.as(DeclReferenceExprSyntax.self),
        base.baseName.text == "self"
    else { return false }
    return true
}

private func namingBoolParameterIsReference(_ expr: ExprSyntax, named name: Swift::String) -> Bool {
    guard let reference = expr.as(DeclReferenceExprSyntax.self) else { return false }
    return reference.baseName.text == name
}
