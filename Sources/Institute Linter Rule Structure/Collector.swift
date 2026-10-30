internal import Lint
internal import SwiftSyntax

internal final class Collector: SyntaxVisitor {
    var primaryTypes: [Primary] = []
    var topLevelExtensions: [ExtensionDeclSyntax] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        for item in Lint.Syntax.Conditional.statements(node.statements) {
            guard case .decl(let decl) = item.item else { continue }
            if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
                topLevelExtensions.append(extensionDecl)
                let prefix = structureDottedName(of: extensionDecl.extendedType) ?? ""
                var nominalMembers: [DeclSyntax] = []
                for member in extensionDecl.memberBlock.members where isPrimary(member.decl) {
                    nominalMembers.append(member.decl)
                }
                if nominalMembers.count == 1 {
                    let nominal = nominalMembers[0]
                    primaryTypes.append(
                        Primary(
                            node: nominal,
                            namePosition: position(of: nominal),
                            extensionPrefix: prefix,
                            wrappingExtension: extensionDecl
                        )
                    )
                }
                continue
            }
            guard isPrimary(decl) else { continue }
            primaryTypes.append(
                Primary(
                    node: decl,
                    namePosition: position(of: decl),
                    extensionPrefix: "",
                    wrappingExtension: nil
                )
            )
        }
        return .skipChildren
    }
}
