public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `untyped throws` = Lint.Rule(
        id: "untyped throws",
        default: .warning,
        controls: [
            .init(
                id: "untyped throws bare function",
                source: "func read() throws {}",
                path: "Sources/Throws Consumer/BareThrows.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "untyped throws concrete function",
                source: "func read() throws(Read.Error) {}",
                path: "Sources/Throws Consumer/TypedThrows.swift",
                expectation: .clean
            ),
            .init(
                id: "untyped throws encodable witness",
                source: "extension Value: Encodable { "
                    + "func encode(to encoder: any Encoder) throws {} }",
                path: "Sources/Throws Consumer/EncodableWitness.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsUntypedVisitor(
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
internal let throwsUntypedMessage: Swift::String =
    "[untyped throws] [API-ERR-001]: bare `throws` erases the error type. Use "
    + "`throws(SpecificError)` so callers know which errors are possible at compile "
    + "time and the error path stays exhaustive. Untyped throws boxes the error as "
    + "`any Error`, which the institute convention forbids. `@Test` and "
    + "`@Suite`-member declarations are exempt (#16 Option C ledger, Entry III.c "
    + "— a test rethrows to the runner and has no API surface)."

@usableFromInline
internal let throwsConformanceForcedAllowlist: [(protocolSuffix: Swift::String, method: Swift::String)] = [
    (protocolSuffix: "TestScoping", method: "provideScope"),
    (protocolSuffix: "Encodable", method: "encode"),
    (protocolSuffix: "Decodable", method: "init(from:)"),
]

internal final class ThrowsUntypedVisitor: SyntaxVisitor {
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

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        guard node.throwsSpecifier.tokenKind == .keyword(.throws) else {
            return .visitChildren
        }
        guard node.type == nil else {
            return .visitChildren
        }
        if Self.isConformanceForcedUntypedThrows(node) {
            return .visitChildren
        }
        if Self.isTestScoped(node) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.throwsSpecifier.positionAfterSkippingLeadingTrivia
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
                identifier: "untyped throws",
                message: throwsUntypedMessage
            )
        )
        return .visitChildren
    }

    static func isConformanceForcedUntypedThrows(_ node: ThrowsClauseSyntax) -> Swift::Bool {
        var enclosingSelector: Swift::String? = nil
        var enclosingSignature: FunctionSignatureSyntax? = nil
        var inheritedTypeSuffixes: Swift::Set<Swift::String> = []
        var cursor: Syntax? = node.parent
        while let current = cursor {
            if enclosingSelector == nil {
                if let function = current.as(FunctionDeclSyntax.self) {
                    enclosingSelector = function.name.text
                    enclosingSignature = function.signature
                } else if let initializer = current.as(InitializerDeclSyntax.self) {
                    enclosingSelector = throwsInitializerSelector(initializer)
                    enclosingSignature = initializer.signature
                }
            }
            if let clause = throwsInheritanceClause(of: current) {
                for inherited in clause.inheritedTypes {
                    inheritedTypeSuffixes.insert(throwsLastNameComponent(inherited.type))
                }
            }
            cursor = current.parent
        }
        guard let selector = enclosingSelector, let signature = enclosingSignature else {
            return false
        }
        guard
            node.position >= signature.position,
            node.endPosition <= signature.endPosition
        else {
            return false
        }
        for entry in throwsConformanceForcedAllowlist where entry.method == selector {
            if inheritedTypeSuffixes.contains(entry.protocolSuffix) { return true }
            if throwsIsCanonicalWitnessSignature(
                protocolSuffix: entry.protocolSuffix,
                parameters: signature.parameterClause.parameters
            ) {
                return true
            }
        }
        return false
    }

    static func isTestScoped(_ node: ThrowsClauseSyntax) -> Swift::Bool {
        var suiteExtensionTargets: [Swift::String] = []
        var cursor: Syntax? = node.parent
        var sourceFile: SourceFileSyntax? = nil
        while let current = cursor {
            if let function = current.as(FunctionDeclSyntax.self),
                Self.hasAttribute(function.attributes, named: "Test")
            {
                return true
            }
            if let decl = current.as(StructDeclSyntax.self),
                Self.hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = current.as(EnumDeclSyntax.self),
                Self.hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = current.as(ClassDeclSyntax.self),
                Self.hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = current.as(ActorDeclSyntax.self),
                Self.hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let ext = current.as(ExtensionDeclSyntax.self) {
                suiteExtensionTargets.append(ext.extendedType.trimmedDescription)
            }
            if let file = current.as(SourceFileSyntax.self) {
                sourceFile = file
            }
            cursor = current.parent
        }
        guard !suiteExtensionTargets.isEmpty, let file = sourceFile else { return false }
        var suitePaths: [Swift::String] = []
        for statement in file.statements {
            Self.collectSuitePaths(from: Syntax(statement.item), prefix: "", into: &suitePaths)
        }
        for target in suiteExtensionTargets where suitePaths.contains(target) {
            return true
        }
        return false
    }

    static func hasAttribute(
        _ attributes: AttributeListSyntax,
        named name: Swift::String
    )
        -> Swift::Bool
    {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            let attrName = attr.attributeName.trimmedDescription
            if attrName == name { return true }
            if attrName.hasSuffix(".\(name)") { return true }
        }
        return false
    }

    static func collectSuitePaths(
        from node: Syntax,
        prefix: Swift::String,
        into collected: inout [Swift::String]
    ) {
        func joined(_ name: Swift::String) -> Swift::String {
            prefix.isEmpty ? name : prefix + "." + name
        }
        if let ext = node.as(ExtensionDeclSyntax.self) {
            let path = joined(ext.extendedType.trimmedDescription)
            for member in ext.memberBlock.members {
                Self.collectSuitePaths(from: Syntax(member.decl), prefix: path, into: &collected)
            }
            return
        }
        var name: Swift::String? = nil
        var attributes: AttributeListSyntax? = nil
        var members: MemberBlockSyntax? = nil
        if let decl = node.as(StructDeclSyntax.self) {
            name = decl.name.text
            attributes = decl.attributes
            members = decl.memberBlock
        } else if let decl = node.as(EnumDeclSyntax.self) {
            name = decl.name.text
            attributes = decl.attributes
            members = decl.memberBlock
        } else if let decl = node.as(ClassDeclSyntax.self) {
            name = decl.name.text
            attributes = decl.attributes
            members = decl.memberBlock
        } else if let decl = node.as(ActorDeclSyntax.self) {
            name = decl.name.text
            attributes = decl.attributes
            members = decl.memberBlock
        }
        guard let name, let attributes, let members else { return }
        let path = joined(name)
        if Self.hasAttribute(attributes, named: "Suite") {
            collected.append(path)
        }
        for member in members.members {
            Self.collectSuitePaths(from: Syntax(member.decl), prefix: path, into: &collected)
        }
    }

}
