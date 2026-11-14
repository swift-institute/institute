public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unchecked call site` = Lint.Rule(
        id: "unchecked call site",
        default: .warning,
        suppression: .next,
        controls: [
            .init(
                id: "unchecked call site consumer bypass",
                source: "let value = Cardinal(__unchecked: raw)",
                path: "Sources/Unchecked Consumer/ConsumerBypass.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unchecked call site declaration parameter",
                source: "struct Cardinal { init(__unchecked _: Int) {} }",
                path: "Sources/Unchecked Consumer/DeclarationParameter.swift",
                expectation: .clean
            ),
            .init(
                id: "unchecked call site own constant",
                source: "extension Cardinal { static let zero = Self(__unchecked: (), 0); static let one = Cardinal(__unchecked: (), 1) }",
                path: "Sources/Unchecked Consumer/Constants.swift",
                expectation: .clean
            ),
            .init(
                id: "unchecked call site foreign constant",
                source: "extension Ordinal { static let zero = Cardinal(__unchecked: (), 0) }",
                path: "Sources/Unchecked Consumer/ForeignConstant.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unchecked call site method label",
                source: "func f() { buffer.take(__unchecked: index) }",
                path: "Sources/Unchecked Consumer/MethodLabel.swift",
                expectation: .clean
            ),
            .init(
                id: "unchecked call site extension initializer bottom out",
                source: "extension Cardinal { init(validated value: Int) { "
                    + "self.init(__unchecked: value) } }",
                path: "Sources/Unchecked Consumer/ExtensionInitializer.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = UncheckedVisitor(
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
internal let uncheckedCallSiteMessage: Swift::String =
    "[unchecked call site] [CONV-016]: `__unchecked:` at a call site is a Tier-5 "
    + "last-resort bypass of the typed system. Prefer `.retag()` (Tier 1) or `.map()` "
    + "(Tier 2) before resorting to `__unchecked:`. The [CONV-001] extension-init "
    + "bottom-out does NOT fire: a call sitting directly in an `extension` "
    + "initializer's body that constructs that extension's own type. "
    + "**Accept-as-warning** disposition (rule fires legitimately, leave the "
    + "warning): a bottom-out spelled some other way — a nominal-type-body "
    + "initializer, a private same-package factory function, or an extension init "
    + "constructing a sibling type. Whether such a site is the sanctioned "
    + "bottom-out is package-level knowledge, not syntax; the warning is the "
    + "review signal. If this site is the typed-system "
    + "bottom-out outside the recognized shape, "
    + "escalate to supervisor and apply "
    + "`// swift-linter:disable:next unchecked call site` with a "
    + "`// REASON: <citation>` continuation."

internal func uncheckedIsExtensionInitBottomOut(
    call: FunctionCallExprSyntax,
    at node: Syntax
) -> Swift::Bool {
    var current: Syntax? = node.parent
    var initializer: InitializerDeclSyntax?
    while let candidate = current {
        if let found = candidate.as(InitializerDeclSyntax.self) {
            initializer = found
            break
        }
        if candidate.is(ClosureExprSyntax.self)
            || candidate.is(FunctionDeclSyntax.self)
            || candidate.is(AccessorDeclSyntax.self)
            || candidate.is(SubscriptDeclSyntax.self)
            || candidate.is(DeinitializerDeclSyntax.self)
        {
            return false
        }
        current = candidate.parent
    }
    guard let initializer else { return false }
    var owning: Syntax? = initializer.parent
    var extended: TypeSyntax?
    while let candidate = owning {
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            extended = extensionDecl.extendedType
            break
        }
        if candidate.is(StructDeclSyntax.self)
            || candidate.is(ClassDeclSyntax.self)
            || candidate.is(EnumDeclSyntax.self)
            || candidate.is(ActorDeclSyntax.self)
        {
            return false
        }
        owning = candidate.parent
    }
    guard let extended else { return false }
    let owner = uncheckedTypeNameTail(extended.trimmedDescription)
    return uncheckedCalleeNames(owner, in: call.calledExpression)
}

/// A constructor or static factory: a type name, `.init`, `Self`, `X.Y`, or `Foo.make(...)`. `buffer.take(__unchecked:)`
/// on an instance is a method whose label merely reads the same, not the brand's bypass.
internal func uncheckedIsConstruction(_ callee: ExprSyntax) -> Swift::Bool {
    if let specialized = callee.as(GenericSpecializationExprSyntax.self) {
        return uncheckedIsConstruction(specialized.expression)
    }
    if let reference = callee.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text.first?.isUppercase ?? false
    }
    if let member = callee.as(MemberAccessExprSyntax.self) {
        let name = member.declName.baseName.text
        if name == "init" || (name.first?.isUppercase ?? false) { return true }
        guard let base = member.base else { return true }
        return uncheckedIsConstruction(base)
    }
    return true
}

/// `static let zero = Self(__unchecked: 0)` in the type's own declaration or extension: a constant the brand
/// defines for itself, the same bottom-out as its own initializer.
internal func uncheckedIsOwnConstant(
    call: FunctionCallExprSyntax,
    at node: Syntax
) -> Swift::Bool {
    var current: Syntax? = node.parent
    var inBinding = false
    while let candidate = current {
        if candidate.is(PatternBindingSyntax.self) { inBinding = true }
        if candidate.is(ClosureExprSyntax.self)
            || candidate.is(FunctionDeclSyntax.self)
            || candidate.is(AccessorDeclSyntax.self)
            || candidate.is(InitializerDeclSyntax.self)
            || candidate.is(SubscriptDeclSyntax.self)
        {
            return false
        }
        var owner: Swift::String?
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            owner = uncheckedTypeNameTail(extensionDecl.extendedType.trimmedDescription)
        } else if let decl = candidate.asProtocol((any NamedDeclSyntax).self),
            candidate.is(StructDeclSyntax.self) || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self) || candidate.is(ActorDeclSyntax.self)
        {
            owner = decl.name.text
        }
        if let owner {
            return inBinding && uncheckedCalleeNames(owner, in: call.calledExpression)
        }
        current = candidate.parent
    }
    return false
}

internal func uncheckedTypeNameTail(_ written: Swift::String) -> Swift::String {
    let base = written.split(separator: "<", maxSplits: 1).first.map(Swift::String.init) ?? written
    return base.split(separator: ".").last.map(Swift::String.init) ?? base
}

internal func uncheckedCalleeNames(
    _ owner: Swift::String,
    in callee: ExprSyntax
) -> Swift::Bool {
    if let specialized = callee.as(GenericSpecializationExprSyntax.self) {
        return uncheckedCalleeNames(owner, in: specialized.expression)
    }
    if let reference = callee.as(DeclReferenceExprSyntax.self) {
        let name = reference.baseName.text
        return name == "Self" || name == owner
    }
    if let member = callee.as(MemberAccessExprSyntax.self) {
        guard member.declName.baseName.text == "init" else { return false }
        guard let base = member.base else { return true }
        return uncheckedCalleeNames(owner, in: base)
            || base.as(DeclReferenceExprSyntax.self)?.baseName.text == "self"
    }
    return false
}

internal final class UncheckedVisitor: SyntaxVisitor {
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

    override func visit(_ node: LabeledExprSyntax) -> SyntaxVisitorContinueKind {
        guard let label = node.label, label.text == "__unchecked" else {
            return .visitChildren
        }
        guard let call = node.parent?.parent?.as(FunctionCallExprSyntax.self) else {
            return .visitChildren
        }
        if uncheckedIsExtensionInitBottomOut(call: call, at: Syntax(node)) {
            return .visitChildren
        }
        if !uncheckedIsConstruction(call.calledExpression) {
            return .visitChildren
        }
        if uncheckedIsOwnConstant(call: call, at: Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(for: label.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "unchecked call site",
                message: uncheckedCallSiteMessage
            )
        )
        return .visitChildren
    }
}
