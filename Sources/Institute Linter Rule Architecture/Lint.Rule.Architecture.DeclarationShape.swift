public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `architecture namespace shape` = Lint.Rule(
        id: "architecture namespace shape",
        default: .warning,
        controls: [
            .init(
                id: "architecture namespace shape instance member",
                source: "public enum Render { public func run() {} }",
                path: "Sources/Architecture Core/InstanceMember.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "architecture namespace shape static member",
                source: "public enum Render { public static func run() {} }",
                path: "Sources/Architecture Core/StaticMember.swift",
                expectation: .clean
            ),
            .init(
                id: "architecture namespace shape inhabited enum",
                source: "public enum Render { case ready; public func run() {} }",
                path: "Sources/Architecture Core/InhabitedEnum.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ArchitectureNamespaceShapeVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let architectureNamespaceShapeMessage: Swift::String =
    "[architecture namespace shape] [ARCH-FOUND-001]: a caseless enum is a "
    + "namespace — it is uninhabited, so this instance member can never be "
    + "called. Either mark the member `static` (namespace intent) or make the "
    + "type inhabited: add cases, or declare a `struct` (value intent)."

internal final class ArchitectureNamespaceShapeVisitor: SyntaxVisitor {
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

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let members = node.memberBlock.members
        let hasCases = members.contains { member in
            member.decl.is(EnumCaseDeclSyntax.self)
        }
        guard !hasCases else { return .visitChildren }
        guard node.inheritanceClause == nil else { return .visitChildren }
        for member in members {
            guard let offender = architectureNamespaceShapeInstanceMember(member.decl) else {
                continue
            }
            let location = converter.location(
                for: offender.positionAfterSkippingLeadingTrivia
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
                    identifier: "architecture namespace shape",
                    message: architectureNamespaceShapeMessage
                )
            )
        }
        return .visitChildren
    }
}

private func architectureNamespaceShapeInstanceMember(
    _ declaration: DeclSyntax
) -> Syntax? {
    if let function = declaration.as(FunctionDeclSyntax.self) {
        return architectureNamespaceShapeIsTypeMember(function.modifiers)
            ? nil : Syntax(function)
    }
    if let variable = declaration.as(VariableDeclSyntax.self) {
        return architectureNamespaceShapeIsTypeMember(variable.modifiers)
            ? nil : Syntax(variable)
    }
    if let subscriptDeclaration = declaration.as(SubscriptDeclSyntax.self) {
        return architectureNamespaceShapeIsTypeMember(subscriptDeclaration.modifiers)
            ? nil : Syntax(subscriptDeclaration)
    }
    if let initializer = declaration.as(InitializerDeclSyntax.self) {
        return Syntax(initializer)
    }
    return nil
}

private func architectureNamespaceShapeIsTypeMember(
    _ modifiers: DeclModifierListSyntax
) -> Swift::Bool {
    modifiers.contains { modifier in
        modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
    }
}
