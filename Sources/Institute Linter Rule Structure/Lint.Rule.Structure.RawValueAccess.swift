public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `raw value access` = Lint.Rule(
        id: "raw value access",
        default: .warning,
        controls: [
            .init(
                id: "raw value access consumer",
                source: "func value(_ tag: Tag) -> Int { tag.rawValue }",
                path: "Sources/Structure Core/Consumer.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "raw value access initializer boundary",
                source: "struct Wrapper { init(_ tag: Tag) { _ = tag.rawValue } }",
                path: "Sources/Structure Core/Wrapper.swift",
                expectation: .clean
            ),
            .init(
                id: "raw value access enclosing self",
                source: "struct Tag { func value() -> Int { self.rawValue } }",
                path: "Sources/Structure Core/Tag.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = StructureRawValueAccessVisitor(
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
internal let structureRawValueAccessMessage: Swift::String =
    "[raw value access] [PATTERN-017]: `.rawValue` at a "
    + "consumer call site bypasses the typed-conversion ladder. These "
    + "accessors are reserved for the brand-newtype's own initializers — "
    + "the typed-conversion boundary the ladder terminates in — and "
    + "same-package implementations. Only the directly enclosing "
    + "initializer counts; a closure or nested function inside an "
    + "initializer is ordinary consumer code and still fires. Prefer the "
    + "typed operation. Same-package implementation sites do NOT fire when "
    + "the receiver is the enclosing type's own instance — `self.rawValue`, "
    + "or a parameter written `Self` / the enclosing type's own name (the "
    + "brand's own operators and serializers). A stored member of `self` "
    + "(`self.tag.rawValue`) is a foreign brand and still fires. "
    + "**Accept-as-warning** disposition (rule fires legitimately, leave "
    + "the warning): a same-package implementation whose receiver is "
    + "neither of those two spellings — a local `let` bound from a foreign "
    + "brand, or a parameter written as a typealias of the enclosing type. "
    + "Whether two written names denote one type is type-checker knowledge, "
    + "not syntax; the warning is the review signal. "
    + "Suppress with "
    + "`// swift-linter:disable:next raw value access` and a `// REASON:` "
    + "continuation for legitimate same-package use."

internal let structureRawValueAccessFlaggedAccessors: Swift::Set<Swift::String> = ["rawValue"]

internal func structureEnclosingParameter(
    named name: Swift::String,
    at node: Syntax
) -> FunctionParameterSyntax? {
    var current: Syntax? = node.parent
    while let candidate = current {
        if candidate.is(ClosureExprSyntax.self) { return nil }
        var parameters: FunctionParameterListSyntax?
        if let function = candidate.as(FunctionDeclSyntax.self) {
            parameters = function.signature.parameterClause.parameters
        } else if let initializer = candidate.as(InitializerDeclSyntax.self) {
            parameters = initializer.signature.parameterClause.parameters
        } else if let subscriptDecl = candidate.as(SubscriptDeclSyntax.self) {
            parameters = subscriptDecl.parameterClause.parameters
        }
        if let parameters {
            for parameter in parameters
            where (parameter.secondName ?? parameter.firstName).text == name {
                return parameter
            }
            return nil
        }
        current = candidate.parent
    }
    return nil
}

internal func structureNormalizedTypeName(_ type: TypeSyntax) -> Swift::String {
    var current = type
    while true {
        if let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
            continue
        }
        if let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
            continue
        }
        if let implicit = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = implicit.wrappedType
            continue
        }
        break
    }
    if let member = current.as(MemberTypeSyntax.self) { return member.name.text }
    if let identifier = current.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    return current.trimmedDescription
}

internal func structureEnclosingTypeNames(at node: Syntax) -> Swift::Set<Swift::String> {
    var names: Swift::Set<Swift::String> = []
    var current: Syntax? = node.parent
    while let candidate = current {
        if let structDecl = candidate.as(StructDeclSyntax.self) {
            names.insert(structDecl.name.text)
        }
        if let classDecl = candidate.as(ClassDeclSyntax.self) { names.insert(classDecl.name.text) }
        if let enumDecl = candidate.as(EnumDeclSyntax.self) { names.insert(enumDecl.name.text) }
        if let actorDecl = candidate.as(ActorDeclSyntax.self) { names.insert(actorDecl.name.text) }
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            names.insert(structureNormalizedTypeName(extensionDecl.extendedType))
        }
        current = candidate.parent
    }
    return names
}

internal final class StructureRawValueAccessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var bodyDepth: Swift::Int = 0

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: FunctionDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: InitializerDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: DeinitializerDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: AccessorDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        if structureIsShorthandGetterAccessorBlock(Syntax(node)) {
            bodyDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: AccessorBlockSyntax) {
        if structureIsShorthandGetterAccessorBlock(Syntax(node)) {
            bodyDepth -= 1
        }
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard bodyDepth > 0 else { return .visitChildren }
        let name = node.declName.baseName.text
        guard structureRawValueAccessFlaggedAccessors.contains(name) else {
            return .visitChildren
        }
        if isDirectlyInsideInitializer(Syntax(node)) {
            return .visitChildren
        }
        if let receiver = node.base, receiverLooksLikeEnumCaseAccess(receiver) {
            return .visitChildren
        }
        if let receiver = node.base, receiverIsEnclosingTypeInstance(receiver, at: Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.declName.baseName.positionAfterSkippingLeadingTrivia
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
                identifier: "raw value access",
                message: structureRawValueAccessMessage
            )
        )
        return .visitChildren
    }

    private func isDirectlyInsideInitializer(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if candidate.is(InitializerDeclSyntax.self) { return true }
            if candidate.is(FunctionDeclSyntax.self)
                || candidate.is(AccessorDeclSyntax.self)
                || structureIsShorthandGetterAccessorBlock(candidate)
                || candidate.is(ClosureExprSyntax.self)
                || candidate.is(DeinitializerDeclSyntax.self)
                || candidate.is(SubscriptDeclSyntax.self)
            {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func receiverIsEnclosingTypeInstance(
        _ receiver: ExprSyntax,
        at node: Syntax
    ) -> Swift::Bool {
        guard let reference = receiver.as(DeclReferenceExprSyntax.self) else { return false }
        let name = reference.baseName.text
        if name == "self" { return true }
        guard let parameter = structureEnclosingParameter(named: name, at: node) else {
            return false
        }
        let written = structureNormalizedTypeName(parameter.type)
        if written == "Self" { return true }
        return structureEnclosingTypeNames(at: node).contains(written)
    }

    private func receiverLooksLikeEnumCaseAccess(_ base: ExprSyntax) -> Swift::Bool {
        guard let caseAccess = base.as(MemberAccessExprSyntax.self),
            let typeBase = caseAccess.base
        else { return false }
        return isTypeChain(typeBase)
    }

    private func isTypeChain(_ expr: ExprSyntax) -> Swift::Bool {
        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            return ref.baseName.text.first?.isUppercase ?? false
        }
        if let member = expr.as(MemberAccessExprSyntax.self),
            let base = member.base
        {
            return isTypeChain(base)
                && (member.declName.baseName.text.first?.isUppercase ?? false)
        }
        return false
    }
}
