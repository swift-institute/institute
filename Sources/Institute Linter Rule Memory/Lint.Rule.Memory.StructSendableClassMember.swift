public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `sendable struct with class member` = Lint.Rule(
        id: "sendable struct with class member",
        default: .error,
        controls: [
            .init(
                id: "sendable struct with class member unchecked",
                source: "final class Storage {}\nstruct Box: @unchecked Sendable { var storage: Storage }",
                path: "Sources/Memory Core/UncheckedClassStorage.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sendable struct with class member plain",
                source: "final class Storage {}\nstruct Box: Sendable { var storage: Storage }",
                path: "Sources/Memory Core/PlainSendableClassStorage.swift",
                expectation: .clean
            ),
            .init(
                id: "sendable struct with class member value",
                source: "struct Box: @unchecked Sendable { var count: Int }",
                path: "Sources/Memory Core/UncheckedValueStorage.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let collector = MemoryStructSendableClassMemberClassCollector(viewMode: .sourceAccurate)
            collector.walk(source.tree)
            let visitor = MemoryStructSendableClassMemberVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                declaredClassNames: collector.names
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let memoryStructSendableClassMemberMessage: Swift::String =
    "[sendable struct with class member] [IMPL-076]: `struct: @unchecked Sendable` "
    + "wrapping a class-typed stored property asserts a safety property the "
    + "compiler cannot check. If the wrapped class is itself `Sendable`, the "
    + "`@unchecked` is redundant — drop it and conform to plain `Sendable`. If "
    + "it is not, the assertion is unsound: replace the class storage with a "
    + "value type, or move the mutable state behind an actor or a `Mutex`."

@usableFromInline
internal let memoryStructSendableClassMemberKnownClassNames: Swift::Set<Swift::String> = [
    "NSObject", "Thread", "DispatchQueue", "AnyObject",
]

internal final class MemoryStructSendableClassMemberClassCollector: SyntaxVisitor {
    var names: Swift::Set<Swift::String> = []

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)

        var path = node.name.text
        var context: Syntax? = Syntax(node).parent
        while let ctx = context {
            if let ext = ctx.as(ExtensionDeclSyntax.self) {
                path = "\(ext.extendedType.trimmedDescription).\(path)"
            } else if let cls = ctx.as(ClassDeclSyntax.self) {
                path = "\(cls.name.text).\(path)"
            } else if let str = ctx.as(StructDeclSyntax.self) {
                path = "\(str.name.text).\(path)"
            } else if let enm = ctx.as(EnumDeclSyntax.self) {
                path = "\(enm.name.text).\(path)"
            } else if let act = ctx.as(ActorDeclSyntax.self) {
                path = "\(act.name.text).\(path)"
            }
            context = ctx.parent
        }
        names.insert(path)

        return .visitChildren
    }
}

internal func memoryStructSendableClassMemberIsClassType(
    _ name: Swift::String,
    in declared: Swift::Set<Swift::String>
) -> Swift::Bool {
    declared.contains(name) || memoryStructSendableClassMemberKnownClassNames.contains(name)
}

internal func memoryStructSendableClassMemberUncheckedSendable(
    _ clause: InheritanceClauseSyntax?
)
    -> Swift::Bool
{
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        guard let attributed = inherited.type.as(AttributedTypeSyntax.self)
        else { continue }
        var hasUnchecked = false
        for attribute in attributed.attributes {
            if case .attribute(let attr) = attribute,
                let name = attr.attributeName.as(IdentifierTypeSyntax.self),
                name.name.text == "unchecked"
            {
                hasUnchecked = true
            }
        }
        guard hasUnchecked else { continue }
        if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
            identifier.name.text == "Sendable"
        {
            return true
        }
        if let member = attributed.baseType.as(MemberTypeSyntax.self),
            member.name.text == "Sendable",
            let base = member.baseType.as(IdentifierTypeSyntax.self),
            base.name.text == "Swift"
        {
            return true
        }
    }
    return false
}

internal func memoryStructSendableClassMemberIsComputed(_ node: VariableDeclSyntax) -> Swift::Bool {
    for binding in node.bindings {
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .accessors(let list):
                for accessor in list {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get), .keyword(.set),
                        .keyword(._read), .keyword(._modify),
                        .keyword(.unsafeAddress), .keyword(.unsafeMutableAddress),
                        .keyword(.willSet), .keyword(.didSet):
                        return true

                    default: break
                    }
                }

            case .getter:
                return true
            }
        }
    }
    return false
}
