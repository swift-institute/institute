public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `stdlib forwarder outside sli` = Lint.Rule(
        id: "stdlib forwarder outside sli",
        default: .warning,
        controls: [
            .init(
                id: "stdlib forwarder outside sli primary Array",
                source: "extension Array where Element == UInt8 { @_disfavoredOverload public func append(_ value: UInt8) {} }",
                path: "Sources/Binary Core/Forwarder.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "stdlib forwarder outside sli integration Array",
                source: "extension Array where Element == UInt8 { @_disfavoredOverload public func append(_ value: UInt8) {} }",
                path: "Sources/Binary Standard Library Integration/Forwarder.swift",
                expectation: .clean
            ),
            .init(
                id: "stdlib forwarder outside sli institute type",
                source: "extension ArraySlice<Byte> { @_disfavoredOverload public func append(_ value: UInt8) {} }",
                path: "Sources/Binary Core/ByteInputForwarder.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteStdlibForwarderOutsideSLIVisitor(
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
internal let byteStdlibForwarderOutsideSLIMessage: Swift::String =
    "[stdlib forwarder outside sli] [API-BYTE-007]: declaration extends "
    + "a stdlib type (Array, ContiguousArray, ArraySlice, Span, "
    + "UnsafeBufferPointer, …), carries `@_disfavoredOverload`, and "
    + "references `UInt8` in its surface, but lives in a byte-domain "
    + "primary module. Stdlib-interop UInt8 forwarders MUST live in the "
    + "package's `* Standard Library Integration` target (the forwarder "
    + "delegates to the `[Byte]`-typed primary via `.lazy.map(Byte.init)` "
    + "or `[Byte](uint8s)`). Move this declaration to a sibling target "
    + "named `<Package> Standard Library Integration`. "
    + "(Extensions on INSTITUTE types with UInt8-accepting "
    + "`@_disfavoredOverload` convenience inits/methods are legitimate "
    + "primary-module surface and do NOT fire this rule.)"

internal final class ByteStdlibForwarderOutsideSLIVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private let hostIsSLI: Swift::Bool

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.hostIsSLI = byteStdlibForwarderHostIsSLI(source.filePath)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hostIsSLI else { return .visitChildren }
        guard byteStdlibForwarderHasDisfavoredOverload(node.attributes) else {
            return .visitChildren
        }
        let enclosing = byteStdlibForwarderEnclosingExtension(Syntax(node))
        guard let enclosing else { return .visitChildren }
        guard byteStdlibForwarderTypeIsStdlibType(enclosing.extendedType) else {
            return .visitChildren
        }
        if byteStdlibForwarderFunctionMentionsUInt8(node)
            || byteStdlibForwarderExtensionConstraintMentionsUInt8(enclosing)
        {
            emit(at: node.funcKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hostIsSLI else { return .visitChildren }
        guard byteStdlibForwarderHasDisfavoredOverload(node.attributes) else {
            return .visitChildren
        }
        let enclosing = byteStdlibForwarderEnclosingExtension(Syntax(node))
        guard let enclosing else { return .visitChildren }
        guard byteStdlibForwarderTypeIsStdlibType(enclosing.extendedType) else {
            return .visitChildren
        }
        if byteStdlibForwarderInitializerMentionsUInt8(node)
            || byteStdlibForwarderExtensionConstraintMentionsUInt8(enclosing)
        {
            emit(at: node.initKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
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
                identifier: "stdlib forwarder outside sli",
                message: byteStdlibForwarderOutsideSLIMessage
            )
        )
    }
}

private func byteStdlibForwarderHostIsSLI(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true).map(
        Swift::String.init
    )
    for index in components.indices.reversed() where components[index] == "Sources" {
        let targetIndex = components.index(after: index)
        guard targetIndex < components.endIndex else { return false }
        return components[targetIndex].hasSuffix("Standard Library Integration")
    }
    return false
}

private func byteStdlibForwarderHasDisfavoredOverload(
    _ attributes: AttributeListSyntax
)
    -> Swift::Bool
{
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "_disfavoredOverload" {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderFunctionMentionsUInt8(_ node: FunctionDeclSyntax) -> Swift::Bool {
    for parameter in node.signature.parameterClause.parameters {
        if byteStdlibForwarderTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    if let returnClause = node.signature.returnClause {
        if byteStdlibForwarderTypeMentionsUInt8(returnClause.type) {
            return true
        }
    }
    if let whereClause = node.genericWhereClause {
        if byteStdlibForwarderWhereClauseMentionsUInt8(whereClause) {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderInitializerMentionsUInt8(
    _ node: InitializerDeclSyntax
)
    -> Swift::Bool
{
    for parameter in node.signature.parameterClause.parameters {
        if byteStdlibForwarderTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    if let whereClause = node.genericWhereClause {
        if byteStdlibForwarderWhereClauseMentionsUInt8(whereClause) {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderWhereClauseMentionsUInt8(
    _ whereClause: GenericWhereClauseSyntax
)
    -> Swift::Bool
{
    for requirement in whereClause.requirements {
        if let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) {
            if let rightTS = Syntax(sameType.rightType).as(TypeSyntax.self),
                byteStdlibForwarderTypeMentionsUInt8(rightTS)
            {
                return true
            }
            if let leftTS = Syntax(sameType.leftType).as(TypeSyntax.self),
                byteStdlibForwarderTypeMentionsUInt8(leftTS)
            {
                return true
            }
        }
    }
    return false
}

private func byteStdlibForwarderTypeMentionsUInt8(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(identifier.name.text)
        if leaf == "UInt8" {
            return true
        }
        if let genericArgs = identifier.genericArgumentClause {
            for arg in genericArgs.arguments {
                if let inner = arg.argument.as(TypeSyntax.self),
                    byteStdlibForwarderTypeMentionsUInt8(inner)
                {
                    return true
                }
            }
        }
        return false
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(memberType.name.text)
        if leaf == "UInt8" {
            return true
        }
        if let genericArgs = memberType.genericArgumentClause {
            for arg in genericArgs.arguments {
                if let inner = arg.argument.as(TypeSyntax.self),
                    byteStdlibForwarderTypeMentionsUInt8(inner)
                {
                    return true
                }
            }
        }
        return false
    }
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(arrayType.element)
    }
    if let dictionaryType = type.as(DictionaryTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(dictionaryType.key)
            || byteStdlibForwarderTypeMentionsUInt8(dictionaryType.value)
    }
    if let optionalType = type.as(OptionalTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(optionalType.wrappedType)
    }
    if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(implicitlyUnwrapped.wrappedType)
    }
    if let attributedType = type.as(AttributedTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(attributedType.baseType)
    }
    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(someOrAny.constraint)
    }
    if let tupleType = type.as(TupleTypeSyntax.self) {
        for element in tupleType.elements
        where byteStdlibForwarderTypeMentionsUInt8(element.type) {
            return true
        }
        return false
    }
    if let functionType = type.as(FunctionTypeSyntax.self) {
        for parameter in functionType.parameters
        where byteStdlibForwarderTypeMentionsUInt8(parameter.type) {
            return true
        }
        return byteStdlibForwarderTypeMentionsUInt8(functionType.returnClause.type)
    }
    return false
}

private let byteStdlibForwarderStdlibTypeLeafNames: Swift::Set<Swift::String> = [
    "Array",
    "ContiguousArray",
    "ArraySlice",
    "Sequence",
    "Collection",
    "RangeReplaceableCollection",
    "BidirectionalCollection",
    "RandomAccessCollection",
    "MutableCollection",
    "Span",
    "MutableSpan",
    "RawSpan",
    "OutputSpan",
    "OutputRawSpan",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "UnsafeRawBufferPointer",
    "UnsafeMutableRawBufferPointer",
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "String",
    "Substring",
    "StringProtocol",
    "Dictionary",
    "Set",
    "Range",
    "ClosedRange",
    "Optional",
    "Result",
]

private func byteStdlibForwarderEnclosingExtension(_ node: Syntax) -> ExtensionDeclSyntax? {
    var current: Syntax? = node.parent
    while let parent = current {
        if let extensionDecl = parent.as(ExtensionDeclSyntax.self) {
            return extensionDecl
        }
        current = parent.parent
    }
    return nil
}

private func byteStdlibForwarderExtensionConstraintMentionsUInt8(
    _ ext: ExtensionDeclSyntax
)
    -> Swift::Bool
{
    if let whereClause = ext.genericWhereClause,
        byteStdlibForwarderWhereClauseMentionsUInt8(whereClause)
    {
        return true
    }
    return byteStdlibForwarderTypeMentionsUInt8(ext.extendedType)
}

private func byteStdlibForwarderTypeIsStdlibType(_ type: TypeSyntax) -> Swift::Bool {
    if let memberType = type.as(MemberTypeSyntax.self) {
        if let baseIdentifier = memberType.baseType.as(IdentifierTypeSyntax.self),
            Lint.Syntax.Identifier.unescaped(baseIdentifier.name.text) == "Swift"
        {
            return true
        }
        return false
    }
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(identifier.name.text)
        guard byteStdlibForwarderStdlibTypeLeafNames.contains(leaf) else { return false }
        let arguments = identifier.genericArgumentClause?.arguments ?? []
        return arguments.allSatisfy { argument in
            guard case .type(let argumentType) = argument.argument else { return true }
            return byteStdlibForwarderTypeIsStdlibType(argumentType)
                || byteStdlibForwarderTypeIsStdlibScalar(argumentType)
        }
    }
    return false
}

private func byteStdlibForwarderTypeIsStdlibScalar(_ type: TypeSyntax) -> Swift::Bool {
    let name: Swift::String? =
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            Lint.Syntax.Identifier.unescaped(identifier.name.text)
        } else if let member = type.as(MemberTypeSyntax.self),
            member.baseType.trimmedDescription == "Swift"
        {
            Lint.Syntax.Identifier.unescaped(member.name.text)
        } else {
            nil
        }
    return name.map(byteStdlibForwarderStdlibScalarNames.contains) ?? false
}

private let byteStdlibForwarderStdlibScalarNames: Swift::Set<Swift::String> = [
    "UInt8", "Int8", "UInt16", "Int16", "UInt32", "Int32", "UInt64", "Int64",
    "UInt", "Int", "Bool", "Character", "Double", "Float",
]
