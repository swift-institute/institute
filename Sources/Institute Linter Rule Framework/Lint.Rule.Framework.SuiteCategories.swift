public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `suite categories` = Lint.Rule(
        id: "suite categories",
        default: .warning,
        controls: [
            .init(
                id: "suite categories missing",
                source: "@Suite struct Example {}",
                path: "Sources/Framework Core/MissingCategories.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "suite categories canonical",
                source: "@Suite struct Example { @Suite struct Unit {}; @Suite struct `Edge Case` {}; @Suite struct Integration {} }",
                path: "Sources/Framework Core/CanonicalCategories.swift",
                expectation: .clean
            ),
            .init(
                id: "suite categories nested nominal",
                source: "enum Host { @Suite struct Example {} }",
                path: "Sources/Framework Core/NestedNominal.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = FrameworkSuiteCategoriesVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            guard let contents = frameworkSuiteCategoriesFixed(source) else { return .unchanged }
            return .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let frameworkSuiteCategoriesMessage: Swift::String =
    "[suite categories] [TEST-005]: top-level `@Suite struct` MUST contain "
    + "all three canonical sub-suites declared via nested "
    + "`@Suite struct (Unit | \\`Edge Case\\` | Integration)`. "
    + "Fixed categories enable cross-package grep-ability per `[TEST-005]`. "
    + "Performance benchmarking is OUT of the test-framework scope — done "
    + "via separate benchmark packages per the `benchmark` skill. A "
    + "`Performance` sub-suite may still exist (rule won't fire on extras) "
    + "but is no longer required."

internal final class FrameworkSuiteCategoriesVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard suiteCategoriesHasSuiteAttribute(node.attributes) else {
            return .visitChildren
        }
        guard suiteCategoriesIsTopLevel(Syntax(node)) else {
            return .visitChildren
        }
        let missing = suiteCategoriesMissingFromBody(node.memberBlock)
        if !missing.isEmpty {
            emit(at: node.name.positionAfterSkippingLeadingTrivia, missing: missing)
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition, missing: [Swift::String]) {
        let location = converter.location(for: position)
        let missingList = missing.joined(separator: ", ")
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "suite categories",
                message: frameworkSuiteCategoriesMessage + " Missing: \(missingList)."
            )
        )
    }
}

internal func suiteCategoriesHasSuiteAttribute(_ attrs: AttributeListSyntax) -> Swift::Bool {
    for attr in attrs {
        guard case .attribute(let a) = attr else { continue }
        let name = a.attributeName.trimmedDescription
        if name == "Suite" || name.hasSuffix(".Suite") {
            return true
        }
    }
    return false
}

internal func suiteCategoriesIsTopLevel(_ node: Syntax) -> Swift::Bool {
    var current = node.parent
    while let parent = current {
        if parent.is(ExtensionDeclSyntax.self) {
            current = parent.parent
            continue
        }
        if parent.is(StructDeclSyntax.self)
            || parent.is(EnumDeclSyntax.self)
            || parent.is(ClassDeclSyntax.self)
            || parent.is(ActorDeclSyntax.self)
        {
            return false
        }
        current = parent.parent
    }
    return true
}

private let suiteCategoriesCanonical: [Swift::String] = [
    "Unit", "`Edge Case`", "Integration",
]

internal func suiteCategoriesMissingFromBody(_ memberBlock: MemberBlockSyntax) -> [Swift::String] {
    var declared = Set<Swift::String>()
    for member in memberBlock.members {
        guard let structDecl = member.decl.as(StructDeclSyntax.self) else { continue }
        guard suiteCategoriesHasSuiteAttribute(structDecl.attributes) else { continue }
        let raw = structDecl.name.text
        let stripped = Lint.Syntax.Identifier.unescaped(raw)
        switch stripped {
        case "Unit": declared.insert("Unit")
        case "Edge Case": declared.insert("`Edge Case`")
        case "Integration": declared.insert("Integration")
        default: continue
        }
    }
    return suiteCategoriesCanonical.filter { !declared.contains($0) }
}
