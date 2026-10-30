public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `manifest naming grammar` = Lint.Rule(
        id: "manifest naming grammar",
        default: .warning,
        controls: [
            .init(
                id: "manifest naming grammar concatenated target",
                source: "let package = Package(name: \"swift-example\", "
                    + "targets: [.executableTarget(name: \"InstituteArchitectureCLI\")] )",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "manifest naming grammar spaced target",
                source: "let package = Package(name: \"swift-example\", "
                    + "targets: [.executableTarget(name: \"Institute Architecture CLI\")] )",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "manifest naming grammar reported once at the declaration",
                source: "let package = Package(name: \"swift-example\", targets: ["
                    + ".target(name: \"QueueDoubleEnded\"), "
                    + ".target(name: \"Consumer\", dependencies: [.target(name: \"QueueDoubleEnded\")]), "
                    + ".testTarget(name: \"Consumer Tests\", dependencies: [.target(name: \"QueueDoubleEnded\")])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "manifest naming grammar upstream product",
                source: "let package = Package(name: \"swift-example\", "
                    + "targets: [.target(name: \"Consumer\", dependencies: "
                    + "[.product(name: \"OrderedCollections\", package: \"swift-collections\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard namingIsPackageManifest(source.file.filePath) else { return [] }
            let visitor = NamingManifestGrammarVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

internal func namingManifestIsKebabSlug(_ name: Swift::String) -> Swift::Bool {
    guard !name.isEmpty else { return false }
    var previousWasHyphen = true
    for character in name {
        if character == "-" {
            if previousWasHyphen { return false }
            previousWasHyphen = true
            continue
        }
        guard character.isLowercase || character.isNumber else { return false }
        guard character.isASCII else { return false }
        previousWasHyphen = false
    }
    return !previousWasHyphen
}

internal func namingManifestCompoundWords(in name: Swift::String) -> [Swift::String] {
    name.split(separator: " ").map(Swift::String.init).filter(namingWordIsCompound)
}

@usableFromInline
internal func namingManifestGrammarSlugMessage(_ name: Swift::String) -> Swift::String {
    "[manifest naming grammar]: package name '\(name)' is not a kebab-case "
        + "slug — the package name must match `[a-z0-9]+(-[a-z0-9]+)*` "
        + "(e.g. `institute-application`)"
}

@usableFromInline
internal func namingManifestGrammarNameMessage(
    _ name: Swift::String,
    words: [Swift::String]
) -> Swift::String {
    "[manifest naming grammar]: declared name '\(name)' contains "
        + "concatenated word\(words.count == 1 ? "" : "s") "
        + words.map { "'\($0)'" }.joined(separator: ", ")
        + " — product and target names use the spaced Nest.Name form "
        + "(e.g. `Institute Architecture CLI`, not `InstituteArchitectureCLI`)"
}

@usableFromInline
internal func namingManifestGrammarPathMessage(
    name: Swift::String,
    segment: Swift::String
) -> Swift::String {
    "[manifest naming grammar]: target '\(name)' declares path segment "
        + "'\(segment)', which differs from the target name only by "
        + "spacing — the directory name must correspond exactly to the "
        + "declared spaced target name"
}

private let namingManifestDeclaringFactories: Swift::Set<Swift::String> = [
    "library", "executable", "target", "testTarget", "executableTarget", "macro", "plugin",
    "systemLibrary",
]

private let namingManifestTargetFactories: Swift::Set<Swift::String> = [
    "target", "testTarget", "executableTarget", "macro", "plugin", "systemLibrary",
]

private func namingManifestIsInsideDependencies(_ node: Syntax) -> Swift::Bool {
    var current = node.parent
    while let candidate = current {
        if let labeled = candidate.as(LabeledExprSyntax.self), labeled.label?.text == "dependencies" {
            return true
        }
        current = candidate.parent
    }
    return false
}

internal final class NamingManifestGrammarVisitor: SyntaxVisitor {
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

    private func literalText(_ expression: ExprSyntax) -> (Swift::String, AbsolutePosition)? {
        guard let literal = expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        else { return nil }
        return (segment.content.text, literal.positionAfterSkippingLeadingTrivia)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self),
            reference.baseName.text == "Package"
        {
            for argument in node.arguments where argument.label?.text == "name" {
                guard let (name, position) = literalText(argument.expression) else { continue }
                if !namingManifestIsKebabSlug(name) {
                    emit(at: position, message: namingManifestGrammarSlugMessage(name))
                }
            }
            return .visitChildren
        }
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            namingManifestDeclaringFactories.contains(member.declName.baseName.text),
            !namingManifestIsInsideDependencies(Syntax(node))
        else { return .visitChildren }
        var declaredName: Swift::String?
        for argument in node.arguments where argument.label?.text == "name" {
            guard let (name, position) = literalText(argument.expression) else { continue }
            declaredName = name
            let compounds = namingManifestCompoundWords(in: name)
            if !compounds.isEmpty {
                emit(
                    at: position,
                    message: namingManifestGrammarNameMessage(name, words: compounds)
                )
            }
        }
        if namingManifestTargetFactories.contains(member.declName.baseName.text),
            let name = declaredName
        {
            for argument in node.arguments where argument.label?.text == "path" {
                guard let (path, position) = literalText(argument.expression) else { continue }
                guard
                    let segment = path.split(separator: "/", omittingEmptySubsequences: true).last
                        .map(Swift::String.init)
                else { continue }
                let despacedSegment = Swift::String(segment.filter { $0 != " " })
                let despacedName = Swift::String(name.filter { $0 != " " })
                if segment != name, despacedSegment == despacedName {
                    emit(
                        at: position,
                        message: namingManifestGrammarPathMessage(name: name, segment: segment)
                    )
                }
            }
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition, message: Swift::String) {
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
                identifier: "manifest naming grammar",
                message: message
            )
        )
    }
}
