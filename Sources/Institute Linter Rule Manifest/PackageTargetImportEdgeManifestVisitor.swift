package import SwiftSyntax

package final class PackageTargetImportEdgeManifestVisitor: SyntaxVisitor {
    package var manifest = PackageTargetImportEdgeManifest()

    package init() {
        super.init(viewMode: .sourceAccurate)
    }

    private func stringLiteralValue(_ expression: ExprSyntax) -> Swift::String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else { return nil }
        var out = ""
        for segment in literal.segments {
            guard let text = segment.as(StringSegmentSyntax.self) else { return nil }
            out += text.content.text
        }
        return out
    }

    private func argument(
        _ node: FunctionCallExprSyntax,
        labeled label: Swift::String
    ) -> ExprSyntax? {
        for argument in node.arguments where argument.label?.text == label {
            return argument.expression
        }
        return nil
    }

    private func dependency(
        from expression: ExprSyntax
    ) -> PackageTargetImportEdgeTarget.Dependency? {
        if let name = stringLiteralValue(expression) {
            return .byName(name)
        }
        guard let call = expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            let nameExpression = argument(call, labeled: "name"),
            let name = stringLiteralValue(nameExpression)
        else { return nil }
        switch member.declName.baseName.text {
        case "target": return .target(name)
        case "product": return .product(name)
        case "byName": return .byName(name)
        default: return nil
        }
    }

    override package func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        switch member.declName.baseName.text {
        case "package":
            if let expression = argument(node, labeled: "url"),
                let url = stringLiteralValue(expression)
            {
                manifest.urlDependencies.append(url)
            } else if let expression = argument(node, labeled: "path"),
                let path = stringLiteralValue(expression)
            {
                manifest.pathDependencies.append(path)
            }

        case "library":
            if let nameExpression = argument(node, labeled: "name"),
                let name = stringLiteralValue(nameExpression),
                let targetsExpression = argument(node, labeled: "targets"),
                let array = targetsExpression.as(ArrayExprSyntax.self)
            {
                var members: Swift::Set<Swift::String> = []
                for element in array.elements {
                    if let target = stringLiteralValue(element.expression) {
                        members.insert(packageTargetImportEdgeNormalize(target))
                    }
                }
                manifest.products[name] = members
            }

        case "target", "executableTarget", "testTarget", "macro":
            guard let nameExpression = argument(node, labeled: "name"),
                let name = stringLiteralValue(nameExpression)
            else { break }
            var target = PackageTargetImportEdgeTarget()
            target.name = name
            target.namePosition = nameExpression.positionAfterSkippingLeadingTrivia
            switch member.declName.baseName.text {
            case "executableTarget": target.kind = .executableTarget
            case "testTarget": target.kind = .testTarget
            case "macro": target.kind = .macro
            default: target.kind = .target
            }
            if let pathExpression = argument(node, labeled: "path"),
                let path = stringLiteralValue(pathExpression)
            {
                target.explicitPath = path
            }
            if let dependenciesExpression = argument(node, labeled: "dependencies"),
                let array = dependenciesExpression.as(ArrayExprSyntax.self)
            {
                for element in array.elements {
                    if let dependency = dependency(from: element.expression) {
                        target.dependencies.append(dependency)
                    }
                }
            }
            manifest.targets.append(target)
            return .skipChildren

        default:
            break
        }
        return .visitChildren
    }
}
