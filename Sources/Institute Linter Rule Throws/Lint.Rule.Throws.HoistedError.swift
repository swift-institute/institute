public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `hoisted error in public throws` = Lint.Rule(
        id: "hoisted error in public throws",
        default: .warning,
        controls: [
            .init(
                id: "hoisted error in public throws internal spelling",
                source: "public func read() throws(__ReadError) {}",
                path: "Sources/Throws Consumer/PublicHoistedError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "hoisted error in public throws canonical spelling",
                source: "public func read() throws(Read.Error) {}",
                path: "Sources/Throws Consumer/PublicCanonicalError.swift",
                expectation: .clean
            ),
            .init(
                id: "hoisted error in public throws internal API",
                source: "func read() throws(__ReadError) {}",
                path: "Sources/Throws Consumer/InternalHoistedError.swift",
                expectation: .clean
            ),
            .init(
                id: "hoisted error in public throws do statement",
                source: "public func read() { do throws(__ReadError) { try load() } catch { } }",
                path: "Sources/Throws Consumer/DoHoistedError.swift",
                expectation: .clean
            ),
            .init(
                id: "hoisted error in public throws public initializer",
                source: "public struct R { public init() throws(__ReadError) {} }",
                path: "Sources/Throws Consumer/InitHoistedError.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsHoistedErrorVisitor(
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
internal let throwsHoistedErrorMessage: Swift::String =
    "[hoisted error in public throws] [API-ERR-007]: typed-throws positions "
    + "MUST reference the canonical domain path, never a `__`-prefixed "
    + "hoisting workaround. Suppress the rule locally where an older "
    + "toolchain still makes the workaround strictly necessary."

private func hoistedLeafIdentifier(of type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
    return nil
}

/// The throws clause belongs to a public or open function, initializer,
/// subscript or property accessor: the only place the spelling is API.
///
/// A declaration with no access keyword of its own can still be public through a
/// `public extension`, so the enclosing scopes are checked too.
private func isPublicDeclarationThrows(_ clause: ThrowsClauseSyntax) -> Bool {
    var node: Syntax? = clause.parent
    while let current = node {
        if current.is(DoStmtSyntax.self) || current.is(ClosureExprSyntax.self)
            || current.is(CodeBlockSyntax.self)
        {
            return false
        }
        let modifiers: DeclModifierListSyntax?
        if let decl = current.as(FunctionDeclSyntax.self) {
            modifiers = decl.modifiers
        } else if let decl = current.as(InitializerDeclSyntax.self) {
            modifiers = decl.modifiers
        } else if let decl = current.as(SubscriptDeclSyntax.self) {
            modifiers = decl.modifiers
        } else if let decl = current.as(VariableDeclSyntax.self) {
            modifiers = decl.modifiers
        } else {
            node = current.parent
            continue
        }
        let names = modifiers.map { $0.map(\.name.tokenKind) } ?? []
        if names.contains(.keyword(.public)) || names.contains(.keyword(.open)) { return true }
        let restricted: [TokenKind] = [
            .keyword(.internal), .keyword(.package), .keyword(.fileprivate), .keyword(.private),
        ]
        if names.contains(where: restricted.contains) { return false }
        var outer = current.parent
        while let enclosing = outer {
            if let ext = enclosing.as(ExtensionDeclSyntax.self) {
                return ext.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
            }
            outer = enclosing.parent
        }
        return false
    }
    return false
}

internal final class ThrowsHoistedErrorVisitor: SyntaxVisitor {
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
        checkThrowsClause(node)
        return .visitChildren
    }

    private func checkThrowsClause(_ clause: ThrowsClauseSyntax?) {
        guard let clause, let type = clause.type else { return }
        guard isPublicDeclarationThrows(clause) else { return }
        guard let leaf = hoistedLeafIdentifier(of: type) else { return }
        guard leaf.hasPrefix("__") else { return }
        let location = converter.location(for: type.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "hoisted error in public throws",
                message: throwsHoistedErrorMessage
            )
        )
    }
}
