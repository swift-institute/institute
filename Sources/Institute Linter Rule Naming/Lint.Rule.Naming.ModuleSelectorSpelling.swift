public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `module selector spelling` = Lint.Rule(
        id: "module selector spelling",
        default: .warning,
        controls: [
            .init(
                id: "module selector spelling standard library type",
                source: "let value: Swift.String = \"\"\nstruct Failure: Swift.Error {}",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "module selector spelling selector-qualified namespace",
                source: "import W3C_XML\nlet element: W3C_XML::W3C_XML.Element? = nil\nlet kind = W3C_XML::W3C_XML.Element.self",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "module selector spelling unqualified unnumbered namespace",
                source: "import W3C_XML\nlet element: W3C_XML.Element? = nil",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "module selector spelling selector",
                source: "let value: Swift::String = \"\"",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "module selector spelling imported target module",
                source: "import Naming_Core\nlet value = Naming_Core.Value()",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "module selector spelling namespace type",
                source: "import Lint\nlet rule: Lint.Rule? = nil",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "module selector spelling package namespace type",
                source: "import Naming_Core\npublic enum Naming_Core {}\nlet value = Naming_Core.Value()",
                path: "Sources/Naming Core/Naming_Core.swift",
                expectation: .clean
            ),
            .init(
                id: "module selector spelling specification namespace",
                source: "import RFC_6265\nlet cookie: RFC_6265.Cookie? = nil\nlet error = ISO_8824.Error.self",
                path: "Sources/Naming Consumer/Value.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let modules = NamingModuleSelectorImports(viewMode: .sourceAccurate)
            modules.walk(source.tree)
            let visitor = NamingModuleSelectorSpellingVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                modules: modules.names.subtracting(source.types)
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            let modules = NamingModuleSelectorImports(viewMode: .sourceAccurate)
            modules.walk(source.tree)
            let visitor = NamingModuleSelectorSpellingVisitor(
                source: source.file,
                severity: .warning,
                converter: source.converter,
                modules: modules.names.subtracting(source.types)
            )
            visitor.walk(source.tree)
            guard !visitor.periods.isEmpty else { return .unchanged }
            var bytes = Swift::Array(source.tree.description.utf8)
            for offset in visitor.periods.sorted(by: >) {
                bytes.replaceSubrange(offset..<offset + 1, with: "::".utf8)
            }
            return .edits([
                .rewrite(path: source.path, contents: Swift::String(decoding: bytes, as: Swift::UTF8.self))
            ])
        }
    )
}

@usableFromInline
internal let namingModuleSelectorSpellingMessage: Swift::String =
    "[module selector spelling] [SOURCE-MODULE-SELECTOR]: qualify a name by an "
    + "imported target module with a module selector, `Module::Name`, not with "
    + "member syntax `Module.Name`. The standard library keeps `Swift.Error`, and "
    + "a namespace type sharing its module's name is reached as `Module::Module.Name`."

internal final class NamingModuleSelectorImports: SyntaxVisitor {
    var names: Swift::Set<Swift::String> = []

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let module = node.path.first?.name.text, module.contains("_"),
            !Self.isSpecificationNamespace(module)
        {
            names.insert(module)
        }
        return .skipChildren
    }
}

extension NamingModuleSelectorImports {
    static func isSpecificationNamespace(_ module: Swift::String) -> Swift::Bool {
        guard let last = module.split(separator: "_").last, module.split(separator: "_").count > 1
        else { return false }
        return last.allSatisfy(\.isNumber)
    }
}

internal final class NamingModuleSelectorSpellingVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let modules: Swift::Set<Swift::String>
    var matches: [Diagnostic.Record] = []
    var periods: [Swift::Int] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        modules: Swift::Set<Swift::String>
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.modules = modules
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.baseType.as(IdentifierTypeSyntax.self),
            base.moduleSelector == nil,
            base.genericArgumentClause == nil,
            modules.contains(base.name.text)
        {
            emit(at: node.positionAfterSkippingLeadingTrivia)
            periods.append(node.period.positionAfterSkippingLeadingTrivia.utf8Offset)
        }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.base?.as(DeclReferenceExprSyntax.self),
            base.moduleSelector == nil,
            modules.contains(base.baseName.text)
        {
            emit(at: node.positionAfterSkippingLeadingTrivia)
            periods.append(node.period.positionAfterSkippingLeadingTrivia.utf8Offset)
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
                identifier: "module selector spelling",
                message: namingModuleSelectorSpellingMessage
            )
        )
    }
}
