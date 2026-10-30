internal import SwiftSyntax

internal func throwsInitializerSelector(_ node: InitializerDeclSyntax) -> Swift::String {
    var selector = "init("
    for parameter in node.signature.parameterClause.parameters {
        selector += parameter.firstName.text
        selector += ":"
    }
    selector += ")"
    return selector
}

internal func throwsIsCanonicalWitnessSignature(
    protocolSuffix: Swift::String,
    parameters: FunctionParameterListSyntax
) -> Swift::Bool {
    guard parameters.count == 1, let parameter = parameters.first else { return false }
    let parameterTypeSuffix = throwsLastNameComponent(throwsUnwrappedConstraint(parameter.type))
    switch protocolSuffix {
    case "Decodable": return parameterTypeSuffix == "Decoder"
    case "Encodable": return parameterTypeSuffix == "Encoder"
    default: return false
    }
}

internal func throwsUnwrappedConstraint(_ type: TypeSyntax) -> TypeSyntax {
    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) { return someOrAny.constraint }
    return type
}

internal func throwsInheritanceClause(of node: Syntax) -> InheritanceClauseSyntax? {
    if let decl = node.as(ExtensionDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(StructDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ClassDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(EnumDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ActorDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ProtocolDeclSyntax.self) { return decl.inheritanceClause }
    return nil
}

internal func throwsLastNameComponent(_ type: TypeSyntax) -> Swift::String {
    if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
    if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    return type.trimmedDescription
}
