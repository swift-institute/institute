public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `type name capital` = Lint.Rule(
        id: "type name capital",
        default: .warning,
        controls: [
            .init(
                id: "type name capital lowercase struct",
                source: "public struct iTunes {}",
                path: "Sources/Naming Core/iTunes.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "type name capital uppercase types",
                source: "struct Value {}\nenum Kind {}\nclass Box {}\nactor Worker {}\nprotocol Carrier {}",
                path: "Sources/Naming Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "type name capital underscored uppercase",
                source: "public protocol __HashTableProtocol {}\npublic struct _Storage {}",
                path: "Sources/Naming Core/Storage.swift",
                expectation: .clean
            ),
            .init(
                id: "type name capital underscored lowercase",
                source: "struct _storage {}",
                path: "Sources/Naming Core/Storage.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "type name capital backticked names",
                source: "extension ISO_32000 { public enum `10` {} }\npublic protocol `Protocol` {}\nstruct `Binary data` {}",
                path: "Sources/Naming Core/Sections.swift",
                expectation: .clean
            ),
            .init(
                id: "type name capital backticked lowercase",
                source: "enum `default` {}",
                path: "Sources/Naming Core/Default.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "type name capital typealias out of scope",
                source: "public typealias circle = SVG.Circle",
                path: "Sources/Naming Core/Tags.swift",
                expectation: .clean
            ),
            .init(
                id: "type name capital tests out of scope",
                source: "@Suite struct unit {}",
                path: "Tests/Naming Core Tests/Value Tests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else { return [] }
            let visitor = NamingTypeNameCapitalVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

internal func namingTypeNameCapitalMessage(_ name: Swift::String) -> Swift::String {
    "[type name capital]: the type name `\(name)` must start with an uppercase letter "
        + "(after any leading underscores); rename it in UpperCamelCase."
}

internal func namingTypeNameStartsCapital(_ text: Swift::String) -> Swift::Bool {
    let name = text.filter { $0 != "`" }
    guard let first = name.first(where: { $0 != "_" }) else { return true }
    return first.isUppercase || first.isNumber
}

internal final class NamingTypeNameCapitalVisitor: SyntaxVisitor {
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

    private func check(_ name: TokenSyntax) {
        guard !namingTypeNameStartsCapital(name.text) else { return }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "type name capital",
                message: namingTypeNameCapitalMessage(name.text.filter { $0 != "`" })
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name)
        return .visitChildren
    }
}
