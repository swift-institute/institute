public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `minimal type body` = Lint.Rule(
        id: "minimal type body",
        default: .warning,
        controls: [
            .init(
                id: "minimal type body function-local type",
                source: "func f() { struct Local { var value: Int; func read() -> Int { value } } }",
                path: "Tests/Structure Tests/Local.swift",
                expectation: .clean
            ),
            .init(
                id: "minimal type body method",
                source: "struct Value { func read() -> Int { 0 } }",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "minimal type body method in tests",
                source: "struct Value { func read() -> Int { 0 } }",
                path: "Tests/Structure Core Tests/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "minimal type body storage and initializer",
                source: "struct Value { let raw: Int; init(raw: Int) { self.raw = raw } }",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "minimal type body extension method",
                source: "extension Value { func read() -> Int { 0 } }",
                path: "Sources/Structure Core/Value+Read.swift",
                expectation: .clean
            ),
            .init(
                id: "minimal type body property wrapper",
                source: "@propertyWrapper struct Box { var storage: Int; "
                    + "var wrappedValue: Int { get { storage } set { storage = newValue } }; "
                    + "var projectedValue: Box { self } }",
                path: "Sources/Structure Core/Box.swift",
                expectation: .clean
            ),
            .init(
                id: "minimal type body property wrapper other member",
                source: "@propertyWrapper struct Box { var wrappedValue: Int; var doubled: Int { wrappedValue * 2 } }",
                path: "Sources/Structure Core/Box.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if source.file.filePath.split(separator: "/", omittingEmptySubsequences: true).dropLast().contains("Tests") {
                return []
            }
            let visitor = StructureMinimalTypeBodyVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            guard let contents = structureMinimalTypeBodyFixed(source) else { return .unchanged }
            return .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let structureMinimalTypeBodyMessage: Swift::String =
    "[minimal type body] [API-IMPL-008]: type bodies MUST contain "
    + "ONLY stored properties, the canonical initializer(s), and "
    + "(for classes / ~Copyable types) `deinit`. Methods, computed "
    + "properties, static members, nested types, and protocol "
    + "conformances belong in extensions. Minimal bodies make storage "
    + "layout immediately visible and separate stable data from "
    + "evolving behavior."

internal func structureMinimalTypeBodyIsComputedProperty(_ node: VariableDeclSyntax) -> Swift::Bool {
    for binding in node.bindings {
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .accessors(let accessorList):
                for accessor in accessorList {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get), .keyword(.set),
                        .keyword(._read), .keyword(._modify):
                        return true

                    default:
                        continue
                    }
                }

            case .getter:
                return true
            }
        }
    }
    return false
}

/// `wrappedValue` or `projectedValue` of a `@propertyWrapper` type: the compiler looks these up in the
/// type's own declaration only, so they stay in its body even when computed.
internal func structureMinimalTypeBodyIsPropertyWrapperRequirement(
    _ variable: VariableDeclSyntax,
    in block: MemberBlockSyntax
) -> Swift::Bool {
    guard !structureMinimalTypeBodyIsStaticOrClassMember(variable.modifiers) else { return false }
    let attributes: AttributeListSyntax? =
        block.parent?.as(StructDeclSyntax.self)?.attributes
        ?? block.parent?.as(ClassDeclSyntax.self)?.attributes
        ?? block.parent?.as(EnumDeclSyntax.self)?.attributes
        ?? block.parent?.as(ActorDeclSyntax.self)?.attributes
    guard let attributes,
        attributes.contains(where: {
            $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "propertyWrapper"
        })
    else { return false }
    return variable.bindings.contains { binding in
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return false
        }
        return name == "wrappedValue" || name == "projectedValue"
    }
}

internal func structureMinimalTypeBodyIsStaticOrClassMember(
    _ modifiers: DeclModifierListSyntax
)
    -> Swift::Bool
{
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.static), .keyword(.class):
            return true

        default:
            continue
        }
    }
    return false
}

internal final class StructureMinimalTypeBodyVisitor: SyntaxVisitor {
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
                identifier: "minimal type body",
                message: structureMinimalTypeBodyMessage
            )
        )
    }

    private func checkMembers(_ block: MemberBlockSyntax) {
        for member in Lint.Syntax.Conditional.members(block) {
            let decl = member.decl
            if let variable = decl.as(VariableDeclSyntax.self) {
                if structureMinimalTypeBodyIsPropertyWrapperRequirement(variable, in: block) {
                    continue
                }
                if structureMinimalTypeBodyIsStaticOrClassMember(variable.modifiers) {
                    emit(at: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                } else if structureMinimalTypeBodyIsComputedProperty(variable) {
                    emit(at: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                }
                continue
            }
            if let function = decl.as(FunctionDeclSyntax.self) {
                emit(at: function.funcKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let subscriptDecl = decl.as(SubscriptDeclSyntax.self) {
                emit(at: subscriptDecl.subscriptKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let typealiasDecl = decl.as(TypeAliasDeclSyntax.self) {
                let aliasName = typealiasDecl.name.text
                if structureIsProtocolSentinelName(aliasName) {
                    continue
                }
                emit(at: typealiasDecl.typealiasKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let nested = decl.as(StructDeclSyntax.self) {
                if structureMinimalTypeBodyHasExtensionPatternAttribute(nested.attributes) {
                    continue
                }
                emit(at: nested.structKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let nested = decl.as(ClassDeclSyntax.self) {
                if structureMinimalTypeBodyHasExtensionPatternAttribute(nested.attributes) {
                    continue
                }
                emit(at: nested.classKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let nested = decl.as(EnumDeclSyntax.self) {
                if structureMinimalTypeBodyHasExtensionPatternAttribute(nested.attributes) {
                    continue
                }
                emit(at: nested.enumKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let nested = decl.as(ActorDeclSyntax.self) {
                if structureMinimalTypeBodyHasExtensionPatternAttribute(nested.attributes) {
                    continue
                }
                emit(at: nested.actorKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
            if let nested = decl.as(ProtocolDeclSyntax.self) {
                emit(at: nested.protocolKeyword.positionAfterSkippingLeadingTrivia)
                continue
            }
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if structureMinimalTypeBodyIsLocal(Syntax(node)) {
            return .visitChildren
        }
        if structureMinimalTypeBodyHasExtensionPatternAttribute(node.attributes) {
            return .visitChildren
        }
        checkMembers(node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if structureMinimalTypeBodyIsLocal(Syntax(node)) {
            return .visitChildren
        }
        if structureMinimalTypeBodyHasExtensionPatternAttribute(node.attributes) {
            return .visitChildren
        }
        if structureExtendsSyntaxVisitor(node.inheritanceClause) {
            return .visitChildren
        }
        checkMembers(node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        if structureMinimalTypeBodyIsLocal(Syntax(node)) {
            return .visitChildren
        }
        if structureMinimalTypeBodyHasExtensionPatternAttribute(node.attributes) {
            return .visitChildren
        }
        checkMembers(node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if structureMinimalTypeBodyIsLocal(Syntax(node)) {
            return .visitChildren
        }
        if structureMinimalTypeBodyHasExtensionPatternAttribute(node.attributes) {
            return .visitChildren
        }
        checkMembers(node.memberBlock)
        return .visitChildren
    }
}

internal func structureMinimalTypeBodyHasExtensionPatternAttribute(
    _ attributes: AttributeListSyntax
) -> Swift::Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        let name = attr.attributeName.trimmedDescription
        if name == "resultBuilder" || name.hasSuffix(".resultBuilder") {
            return true
        }
        let leaf = name.split(separator: ".").last.map(Swift::String.init) ?? name
        guard let first = leaf.first, first.isUppercase else { continue }
        if structureMinimalTypeBodyNonMacroCapitalisedAttributes.contains(leaf) { continue }
        return true
    }
    return false
}

internal let structureMinimalTypeBodyNonMacroCapitalisedAttributes: Swift::Set<Swift::String> = [
    "MainActor",
    "NSCopying", "NSManaged", "NSApplicationMain",
    "UIApplicationMain",
    "IBOutlet", "IBAction", "IBDesignable", "IBInspectable", "IBSegueAction",
    "GKInspectable",
]

internal func structureMinimalTypeBodyIsLocal(_ node: Syntax) -> Swift::Bool {
    var current = node.parent
    while let candidate = current {
        if candidate.is(CodeBlockSyntax.self) || candidate.is(ClosureExprSyntax.self)
            || candidate.is(AccessorBlockSyntax.self)
        {
            return true
        }
        current = candidate.parent
    }
    return false
}
