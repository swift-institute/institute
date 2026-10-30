public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `convention c representability` = Lint.Rule(
        id: "convention c representability",
        default: .warning,
        controls: [
            .init(
                id: "convention c representability swift struct pointer",
                source: "let callback: @convention(c) "
                    + "(UnsafeMutablePointer<Kernel.Signal.Information>?) -> Void",
                path: "Sources/Platform Core/SwiftStructCallback.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "convention c representability imported c structs",
                source: "public typealias Handler = @convention(c) "
                    + "(Int32, UnsafeMutablePointer<siginfo_t>?, UnsafeMutableRawPointer?) -> Void\n"
                    + "public typealias Sleep = @convention(c) (UnsafeMutablePointer<timespec>?) -> Void",
                path: "Sources/Platform Core/SignalHandler.swift",
                expectation: .clean
            ),
            .init(
                id: "convention c representability unqualified swift struct",
                source: "let callback: @convention(c) (UnsafeMutablePointer<Information>?) -> Void",
                path: "Sources/Platform Core/SwiftStructCallback.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "convention c representability primitive pointer",
                source: "let callback: @convention(c) (UnsafeMutablePointer<Int32>?) -> Void",
                path: "Sources/Platform Core/PrimitiveCallback.swift",
                expectation: .clean
            ),
            .init(
                id: "convention c representability swift convention",
                source: "let callback: (UnsafeMutablePointer<Kernel.Signal.Information>?) -> Void",
                path: "Sources/Platform Core/SwiftCallback.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformConventionCRepresentabilityVisitor(
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
internal let platformConventionCRepresentabilityMessage: Swift::String =
    "[convention c representability] [PLAT-ARCH-005b]: `@convention(c)` "
    + "function type takes `UnsafeMutablePointer<UserType>?` for a "
    + "Swift-defined struct — pure Swift structs (including @safe "
    + "wrappers) are NOT C-representable and the compiler rejects "
    + "them in @convention(c) signatures. Use `OpaquePointer?` or "
    + "`UnsafeMutableRawPointer?` in the callback signature; bind the "
    + "typed wrapper at the callback's first line."

internal func platformConventionCRepresentabilityHasConventionC(
    _ attributes: AttributeListSyntax
)
    -> Swift::Bool
{
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        guard attr.attributeName.trimmedDescription == "convention" else { continue }
        if let arguments = attr.arguments,
            case .argumentList(let labeled) = arguments
        {
            if let first = labeled.first,
                let identifier = first.expression.as(DeclReferenceExprSyntax.self),
                identifier.baseName.text == "c"
            {
                return true
            }
        }
    }
    return false
}

internal func platformConventionCRepresentabilityIsUnsafePointerToUserType(
    _ type: TypeSyntax
)
    -> Swift::Bool
{
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
    guard let identifier = current.as(IdentifierTypeSyntax.self) else {
        return false
    }
    guard
        identifier.name.text == "UnsafeMutablePointer"
            || identifier.name.text == "UnsafePointer"
    else { return false }
    guard let genericArgs = identifier.genericArgumentClause,
        let argument = genericArgs.arguments.first,
        let argumentType = argument.argument.as(TypeSyntax.self)
    else { return false }
    if platformConventionCRepresentabilityIsCInteropReference(argumentType) { return false }
    if platformConventionCRepresentabilityIsStdlibPrimitive(argumentType) { return false }
    if platformConventionCRepresentabilityIsImportedCSpelling(argumentType) { return false }
    return true
}

private func platformConventionCRepresentabilityIsStdlibPrimitive(
    _ type: TypeSyntax
)
    -> Swift::Bool
{
    guard let identifier = type.as(IdentifierTypeSyntax.self) else { return false }
    return platformConventionCRepresentabilityStdlibPrimitiveNames.contains(identifier.name.text)
}

private func platformConventionCRepresentabilityIsImportedCSpelling(
    _ type: TypeSyntax
)
    -> Swift::Bool
{
    guard let identifier = type.as(IdentifierTypeSyntax.self),
        identifier.genericArgumentClause == nil,
        let first = identifier.name.text.first
    else { return false }
    return first.isLowercase
}

private let platformConventionCRepresentabilityStdlibPrimitiveNames: Swift::Set<Swift::String> = [
    "Int8", "Int16", "Int32", "Int64",
    "UInt8", "UInt16", "UInt32", "UInt64",
    "Int", "UInt",
    "Float", "Double",
    "Bool",
    "UnsafeRawPointer", "UnsafeMutableRawPointer", "OpaquePointer",
]

private func platformConventionCRepresentabilityIsCInteropReference(
    _ type: TypeSyntax
)
    -> Swift::Bool
{
    guard let member = type.as(MemberTypeSyntax.self) else { return false }
    var base = member.baseType
    while let nested = base.as(MemberTypeSyntax.self) { base = nested.baseType }
    guard let root = base.as(IdentifierTypeSyntax.self) else { return false }
    return platformPlatformConditionalCLibraryModules.contains(root.name.text)
}

internal final class PlatformConventionCRepresentabilityVisitor: SyntaxVisitor {
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

    override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind {
        guard platformConventionCRepresentabilityHasConventionC(node.attributes) else {
            return .visitChildren
        }
        guard let function = node.baseType.as(FunctionTypeSyntax.self) else {
            return .visitChildren
        }
        for parameter in function.parameters {
            guard
                platformConventionCRepresentabilityIsUnsafePointerToUserType(
                    parameter.type
                )
            else { continue }
            let location = converter.location(
                for: parameter.type.positionAfterSkippingLeadingTrivia
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
                    identifier: "convention c representability",
                    message: platformConventionCRepresentabilityMessage
                )
            )
        }
        return .visitChildren
    }
}
