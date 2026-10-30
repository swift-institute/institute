internal import Lint
internal import SwiftSyntax

internal func structureIsProtocolSentinelName(_ name: Swift::String) -> Swift::Bool {
    return name == "Protocol" || name == "`Protocol`"
}

internal let structureSyntaxVisitorFamilyNames: Swift::Set<Swift::String> = [
    "SyntaxVisitor",
    "SyntaxAnyVisitor",
    "SyntaxRewriter",
]

internal func structureIsShorthandGetterAccessorBlock(_ node: Syntax) -> Swift::Bool {
    guard let block = node.as(AccessorBlockSyntax.self) else { return false }
    if case .getter = block.accessors { return true }
    return false
}

internal func structureIsFileSignificant(_ node: some SyntaxProtocol) -> Swift::Bool {
    var current: Syntax? = Syntax(node).parent
    while let ancestor = current {
        if ancestor.is(SourceFileSyntax.self) {
            return true
        }
        if ancestor.is(ExtensionDeclSyntax.self) || ancestor.is(IfConfigDeclSyntax.self) {
            current = ancestor.parent
            continue
        }
        if ancestor.is(StructDeclSyntax.self)
            || ancestor.is(ClassDeclSyntax.self)
            || ancestor.is(EnumDeclSyntax.self)
            || ancestor.is(ActorDeclSyntax.self)
            || ancestor.is(ProtocolDeclSyntax.self)
            || ancestor.is(FunctionDeclSyntax.self)
            || ancestor.is(InitializerDeclSyntax.self)
            || ancestor.is(DeinitializerDeclSyntax.self)
            || ancestor.is(SubscriptDeclSyntax.self)
            || ancestor.is(AccessorDeclSyntax.self)
            || ancestor.is(AccessorBlockSyntax.self)
            || ancestor.is(ClosureExprSyntax.self)
        {
            return false
        }
        current = ancestor.parent
    }
    return false
}

internal func structureDottedName(of type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let name = Lint.Syntax.Identifier.unescaped(identifier.name.text)
        return identifier.moduleSelector?.moduleName.text == "Swift" ? "Swift.\(name)" : name
    }
    if let member = type.as(MemberTypeSyntax.self) {
        guard let baseName = structureDottedName(of: member.baseType) else {
            return nil
        }
        return "\(baseName).\(Lint.Syntax.Identifier.unescaped(member.name.text))"
    }
    if let metatype = type.as(MetatypeTypeSyntax.self) {
        guard let baseName = structureDottedName(of: metatype.baseType) else {
            return nil
        }
        return "\(baseName).\(Lint.Syntax.Identifier.unescaped(metatype.metatypeSpecifier.text))"
    }
    return nil
}

internal func structureExtendsSyntaxVisitor(_ clause: InheritanceClauseSyntax?) -> Swift::Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        let type = inherited.type
        let leaf: Swift::String? =
            if let identifier = type.as(IdentifierTypeSyntax.self) {
                identifier.name.text
            } else if let member = type.as(MemberTypeSyntax.self) {
                member.name.text
            } else {
                nil
            }
        if let leaf, structureSyntaxVisitorFamilyNames.contains(leaf) {
            return true
        }
    }
    return false
}

internal let structureStdlibProtocolNames: Swift::Set<Swift::String> = [
    "Equatable", "Hashable", "Comparable", "Identifiable",
    "Copyable", "Escapable", "BitwiseCopyable",
    "Sendable", "SendableMetatype",
    "Error", "CustomStringConvertible", "CustomDebugStringConvertible",
    "CustomReflectable", "CustomLeafReflectable", "CustomPlaygroundDisplayConvertible",
    "TextOutputStream", "TextOutputStreamable", "LosslessStringConvertible",
    "CaseIterable", "RawRepresentable", "OptionSet",
    "Encodable", "Decodable", "Codable", "CodingKey",
    "CodingKeyRepresentable",
    "ExpressibleByNilLiteral", "ExpressibleByBooleanLiteral",
    "ExpressibleByIntegerLiteral", "ExpressibleByFloatLiteral",
    "ExpressibleByStringLiteral", "ExpressibleByExtendedGraphemeClusterLiteral",
    "ExpressibleByUnicodeScalarLiteral", "ExpressibleByStringInterpolation",
    "ExpressibleByArrayLiteral", "ExpressibleByDictionaryLiteral",
    "StringInterpolationProtocol",
    "AdditiveArithmetic", "Numeric", "SignedNumeric",
    "BinaryInteger", "FixedWidthInteger", "SignedInteger", "UnsignedInteger",
    "FloatingPoint", "BinaryFloatingPoint", "Strideable",
    "SIMD", "SIMDScalar", "SIMDStorage",
    "Sequence", "IteratorProtocol", "Collection", "BidirectionalCollection",
    "RandomAccessCollection", "MutableCollection", "RangeReplaceableCollection",
    "LazySequenceProtocol", "LazyCollectionProtocol",
    "SetAlgebra", "RangeExpression",
    "StringProtocol", "Unicode.Encoding", "UnicodeCodec",
    "AsyncSequence", "AsyncIteratorProtocol",
    "Actor", "GlobalActor",
    "Executor", "SerialExecutor", "TaskExecutor",
    "AnyObject", "RandomNumberGenerator",
]

internal func structureIsStdlibConformance(_ conformance: Swift::String) -> Swift::Bool {
    if structureStdlibProtocolNames.contains(conformance) { return true }
    guard conformance.hasPrefix("Swift.") else { return false }
    return structureStdlibProtocolNames.contains(
        Swift::String(conformance.dropFirst("Swift.".count))
    )
}

internal func structureIsStdlibOnlyConformanceExtension(
    _ extensionDecl: ExtensionDeclSyntax
) -> Swift::Bool {
    guard let clause = extensionDecl.inheritanceClause, !clause.inheritedTypes.isEmpty else {
        return false
    }
    return clause.inheritedTypes.allSatisfy { inherited in
        guard let name = structureDottedName(of: inherited.type) else { return false }
        return structureIsStdlibConformance(Lint.Syntax.Identifier.unescaped(name))
    }
}

internal func structureModuleSpelling(_ text: Swift::String) -> Swift::String {
    text.replacing("Swift::", with: "Swift.").replacing(#/[A-Za-z_][A-Za-z0-9_]*::/#, with: "")
}
