public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `phantom generic error in typed throws` = Lint.Rule(
        id: "phantom generic error in typed throws",
        default: .warning,
        controls: [
            .init(
                id: "phantom generic error declaration site",
                source: "public struct Parser<Input> { "
                    + "public enum Error: Swift.Error { case invalid } }",
                path: "Sources/Throws Consumer/PhantomErrorDeclaration.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "phantom generic error use site",
                source: "public struct Parser<Input> { "
                    + "public typealias Failure = Parser<Input>.Error }",
                path: "Sources/Throws Consumer/PhantomErrorUse.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "phantom generic error substantive parameter",
                source: "public struct Parser<Input> { "
                    + "public enum Error: Swift.Error { case invalid(Input) } }",
                path: "Sources/Throws Consumer/GenericErrorDeclaration.swift",
                expectation: .clean
            ),
            .init(
                id: "phantom generic error nongeneric owner",
                source: "public struct Parser { public enum Error: Swift.Error { case invalid } }",
                path: "Sources/Throws Consumer/NongenericErrorDeclaration.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsPhantomGenericErrorVisitor(
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
internal let throwsPhantomGenericErrorMessage: Swift::String =
    "[phantom generic error in typed throws] [API-ERR-009]: error type is nested "
    + "in a generic type but never uses its parameter — an accidentally-generic "
    + "`@error` SIL result that can trip `FunctionSignatureOpts` under "
    + "`-O -enable-default-cmo` (`SILArgument.cpp:40`, swiftlang/swift#89617), "
    + "aborting release builds of this package AND of every consumer. Hoist the "
    + "enum to non-generic module scope (`__<Domain>Error`) and keep a "
    + "`public typealias Error` on the generic type so the old spelling still "
    + "resolves — behaviour-preserving, since the cases never used the parameter. "
    + "This shape is necessary but NOT sufficient for the crash (it also needs an "
    + "eliminable argument, which is invisible here): confirm with a release build "
    + "rather than assuming either way."

@usableFromInline
internal let throwsPhantomGenericErrorUseSiteMessage: Swift::String =
    "[phantom generic error in typed throws] [API-ERR-009]: typed-throws position "
    + "names an error type spelled with the enclosing type's generic arguments "
    + "(`Owner<Param>.Error`). If the error enum is NOT yet hoisted, this is the "
    + "`FunctionSignatureOpts` release-build ICE shape "
    + "(`SILArgument.cpp:40`, swiftlang/swift#89617): hoist the enum to non-generic "
    + "module scope and keep a `public typealias Error` for the old spelling. If it "
    + "IS already hoisted, the type is fine and only the spelling is stale — name "
    + "the hoisted type directly (`typealias Failure = __<Domain>Error`) so the "
    + "signature no longer reads as parameterised. Either way, confirm with a "
    + "release build rather than assuming: this shape is necessary but not "
    + "sufficient for the crash."

private let throwsPhantomGenericErrorNames: Set<Swift::String> = ["Error", "Failure"]

private func throwsPhantomLeafName(of type: TypeSyntax) -> Swift::String? {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) { current = optional.wrappedType }
    while let attributed = current.as(AttributedTypeSyntax.self) { current = attributed.baseType }
    if let member = current.as(MemberTypeSyntax.self) { return member.name.text }
    if let identifier = current.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    return nil
}

private func throwsPhantomBaseGenericArguments(_ type: TypeSyntax) -> [Swift::String] {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) { current = optional.wrappedType }
    while let attributed = current.as(AttributedTypeSyntax.self) { current = attributed.baseType }
    guard let member = current.as(MemberTypeSyntax.self) else { return [] }
    var base = member.baseType
    while true {
        if let identifier = base.as(IdentifierTypeSyntax.self) {
            return identifier.genericArgumentClause?.arguments.map {
                $0.argument.trimmedDescription
            }
                ?? []
        }
        if let inner = base.as(MemberTypeSyntax.self) {
            if let clause = inner.genericArgumentClause {
                return clause.arguments.map { $0.argument.trimmedDescription }
            }
            base = inner.baseType
            continue
        }
        return []
    }
}

private func throwsPhantomArgumentsAreInScopeParameters(
    _ arguments: [Swift::String],
    inScope: Set<Swift::String>
) -> Swift::Bool {
    for argument in arguments where inScope.contains(argument) { return true }
    return false
}

private func throwsPhantomDedupKey(_ owner: Swift::String) -> Swift::String {
    let withoutGenerics = owner.prefix { $0 != "<" }
    let leaf = withoutGenerics.split(separator: ".").last.map(Swift::String.init)
    return leaf ?? Swift::String(withoutGenerics)
}

internal func throwsPhantomGenericParameterNames(
    _ clause: GenericParameterClauseSyntax?
) -> [Swift::String] {
    guard let clause else { return [] }
    return clause.parameters.map { $0.name.text }
}

private func throwsPhantomUsesParameterSubstantively(
    _ members: MemberBlockItemListSyntax,
    parameter: Swift::String
) -> Swift::Bool {
    let finder = ThrowsPhantomParameterUseFinder(parameter: parameter)
    for member in members { finder.walk(member) }
    return finder.found
}

internal final class ThrowsPhantomGenericErrorVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private var reported: Set<Swift::String> = []
    private var fileGenerics: [Swift::String: [Swift::String]] = [:]
    private var collected = false

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        if !collected {
            let collector = ThrowsPhantomGenericDeclCollector()
            collector.walk(node)
            fileGenerics = collector.generics
            collected = true
        }
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard throwsPhantomGenericErrorNames.contains(node.name.text) else { return .visitChildren }
        guard throwsPhantomGenericParameterNames(node.genericParameterClause).isEmpty else {
            return .visitChildren
        }
        guard hasCases(node.memberBlock.members) else { return .visitChildren }

        let (owner, parameters) = enclosingGenericScope(Syntax(node))
        guard let owner, !parameters.isEmpty else { return .visitChildren }
        for parameter in parameters
        where throwsPhantomUsesParameterSubstantively(
            node.memberBlock.members,
            parameter: parameter
        ) {
            return .visitChildren
        }
        report(
            at: node.name.positionAfterSkippingLeadingTrivia,
            owner: owner,
            message: throwsPhantomGenericErrorMessage
        )
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "Failure" else { return .visitChildren }
        checkUseSite(node.initializer.value)
        return .visitChildren
    }

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        if let type = node.type { checkUseSite(type) }
        return .visitChildren
    }

    private func checkUseSite(_ type: TypeSyntax) {
        guard let leaf = throwsPhantomLeafName(of: type),
            throwsPhantomGenericErrorNames.contains(leaf)
        else { return }
        let arguments = throwsPhantomBaseGenericArguments(type)
        guard !arguments.isEmpty else { return }
        let inScope = inScopeParameters(Syntax(type))
        guard throwsPhantomArgumentsAreInScopeParameters(arguments, inScope: inScope) else {
            return
        }
        guard let member = type.as(MemberTypeSyntax.self) else { return }
        let owner = member.baseType.trimmedDescription
        report(
            at: type.positionAfterSkippingLeadingTrivia,
            owner: owner,
            message: throwsPhantomGenericErrorUseSiteMessage
        )
    }

    private func hasCases(_ members: MemberBlockItemListSyntax) -> Swift::Bool {
        for member in members where member.decl.is(EnumCaseDeclSyntax.self) { return true }
        return false
    }

    private func enclosingGenericScope(_ node: Syntax) -> (Swift::String?, [Swift::String]) {
        var current = node.parent
        while let parent = current {
            if let decl = parent.as(StructDeclSyntax.self) {
                let parameters = throwsPhantomGenericParameterNames(decl.genericParameterClause)
                if !parameters.isEmpty { return (decl.name.text, parameters) }
            }
            if let decl = parent.as(EnumDeclSyntax.self) {
                let parameters = throwsPhantomGenericParameterNames(decl.genericParameterClause)
                if !parameters.isEmpty { return (decl.name.text, parameters) }
            }
            if let decl = parent.as(ClassDeclSyntax.self) {
                let parameters = throwsPhantomGenericParameterNames(decl.genericParameterClause)
                if !parameters.isEmpty { return (decl.name.text, parameters) }
            }
            if let decl = parent.as(ActorDeclSyntax.self) {
                let parameters = throwsPhantomGenericParameterNames(decl.genericParameterClause)
                if !parameters.isEmpty { return (decl.name.text, parameters) }
            }
            if let ext = parent.as(ExtensionDeclSyntax.self) {
                let path = ext.extendedType.trimmedDescription
                let leaf = path.split(separator: ".").last.map(Swift::String.init) ?? path
                if let parameters = fileGenerics[leaf], !parameters.isEmpty {
                    return (path, parameters)
                }
            }
            current = parent.parent
        }
        return (nil, [])
    }

    private func inScopeParameters(_ node: Syntax) -> Set<Swift::String> {
        var names: Set<Swift::String> = []
        var current = node.parent
        while let parent = current {
            if let decl = parent.as(StructDeclSyntax.self) {
                names.formUnion(throwsPhantomGenericParameterNames(decl.genericParameterClause))
            }
            if let decl = parent.as(EnumDeclSyntax.self) {
                names.formUnion(throwsPhantomGenericParameterNames(decl.genericParameterClause))
            }
            if let decl = parent.as(ClassDeclSyntax.self) {
                names.formUnion(throwsPhantomGenericParameterNames(decl.genericParameterClause))
            }
            if let decl = parent.as(ActorDeclSyntax.self) {
                names.formUnion(throwsPhantomGenericParameterNames(decl.genericParameterClause))
            }
            if let decl = parent.as(FunctionDeclSyntax.self) {
                names.formUnion(throwsPhantomGenericParameterNames(decl.genericParameterClause))
            }
            if let ext = parent.as(ExtensionDeclSyntax.self) {
                let path = ext.extendedType.trimmedDescription
                let leaf = path.split(separator: ".").last.map(Swift::String.init) ?? path
                if let parameters = fileGenerics[leaf] { names.formUnion(parameters) }
            }
            current = parent.parent
        }
        return names
    }

    private func report(
        at position: AbsolutePosition,
        owner: Swift::String,
        message: Swift::String
    ) {
        guard reported.insert(throwsPhantomDedupKey(owner)).inserted else { return }
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
                identifier: "phantom generic error in typed throws",
                message: message
            )
        )
    }
}
