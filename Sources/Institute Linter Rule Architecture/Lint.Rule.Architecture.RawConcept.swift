public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// A public signature holding a concept with an owner as a raw string.
    public static let `raw concept` = Lint.Rule(
        id: "raw concept",
        default: .warning,
        suppression: .both,
        controls: [
            .init(
                id: "raw concept parameter",
                source: "public func read(path: String) {}",
                path: "Sources/Ledger/Read.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "raw concept property and optional",
                source: "public struct Entry {\n    public var path: Swift.String?\n    public let directory: String\n}",
                path: "Sources/Ledger/Entry.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "raw concept initializer, by internal name",
                source: "public struct Entry {\n    public init(at path: String) {}\n}",
                path: "Sources/Ledger/Entry.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "raw concept whole words at the end of a name",
                source: "public struct Entry {\n    public var documentationURL: String\n    public var originalPath: String\n"
                    + "    public var modificationDate: String\n    public var fileName: String\n    public var counterpartyIBAN: String\n}",
                path: "Sources/Ledger/Entry.swift",
                expectation: .findings(5)
            ),
            .init(
                id: "raw concept a word inside another or not at the end",
                source: "public struct Entry {\n    public var onHashChange: String\n    public var hashAlgorithm: String\n    public var shadowed: String\n"
                    + "    public var allocation: String\n    public var direction: String\n    public var pathStyle: String\n}",
                path: "Sources/Ledger/Entry.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept a port as a number",
                source: "public func connect(port: Int) {}\npublic func listen(localPort: UInt16?) {}",
                path: "Sources/Ledger/Connect.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "raw concept a number that isn't a port",
                source: "public func read(path: Int, count: Int) {}",
                path: "Sources/Ledger/Read.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept owner's type",
                source: "public func read(path: File.Path) {}",
                path: "Sources/Ledger/Read.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept not public",
                source: "func read(path: String) {}\npublic struct Entry {\n    let path: String\n}",
                path: "Sources/Ledger/Read.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept leaf target",
                source: "public struct Row {\n    public var path: String\n}",
                path: "Sources/Ledger SQL/Row.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept test",
                source: "public func read(path: String) {}",
                path: "Tests/Ledger Tests/Read.swift",
                expectation: .clean
            ),
            .init(
                id: "raw concept call-site default",
                source: "public func expect(filePath: String = #filePath) {}",
                path: "Sources/Ledger/Expect.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !Lint.Concept.isLeaf(source.file.filePath) else { return [] }
            let visitor = RawConceptVisitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private final class RawConceptVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.signature.parameterClause, modifiers: node.modifiers)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.signature.parameterClause, modifiers: node.modifiers)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Self.isPublic(node.modifiers) else { return .visitChildren }
        for binding in node.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let type = binding.typeAnnotation?.type
            else { continue }
            report(Syntax(binding), name: name, type: type)
        }
        return .visitChildren
    }

    private func check(_ clause: FunctionParameterClauseSyntax, modifiers: DeclModifierListSyntax) {
        guard Self.isPublic(modifiers) else { return }
        for parameter in clause.parameters where !Self.isCallSite(parameter) {
            report(Syntax(parameter), name: (parameter.secondName ?? parameter.firstName).text, type: parameter.type)
        }
    }

    private func report(_ node: Syntax, name: Swift::String, type: TypeSyntax) {
        let owner =
            Self.isRaw(type)
            ? Lint.Concept.owner(of: name)
            : Self.isNumber(type) ? Lint.Concept.owner(of: name, in: Lint.Concept.numbers) : nil
        guard let owner else { return }
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "raw concept",
                message: "[raw concept]: `\(name)` is a raw value in a public signature, and \(owner) owns what it holds. "
                    + "Fix: take \(owner), converting at the leaf. If it is something else, as a URL's path is, suppress "
                    + "this with a reason."
            )
        )
    }

    private static func isPublic(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
        modifiers.contains { $0.name.text == "public" || $0.name.text == "open" }
    }

    private static func isCallSite(_ parameter: FunctionParameterSyntax) -> Swift::Bool {
        parameter.defaultValue?.value.is(MacroExpansionExprSyntax.self) == true
    }

    private static func isNumber(_ type: TypeSyntax) -> Swift::Bool {
        if let optional = type.as(OptionalTypeSyntax.self) { return isNumber(optional.wrappedType) }
        return ["Int", "Swift.Int", "Swift::Int", "UInt16", "Swift.UInt16", "Swift::UInt16"].contains(type.trimmedDescription)
    }

    private static func isRaw(_ type: TypeSyntax) -> Swift::Bool {
        if let optional = type.as(OptionalTypeSyntax.self) { return isRaw(optional.wrappedType) }
        if let array = type.as(ArrayTypeSyntax.self) { return isRaw(array.element) }
        return ["String", "Swift.String", "Swift::String", "Substring", "Swift.Substring"].contains(type.trimmedDescription)
    }
}
