internal import Lint
internal import SwiftSyntax

private let manifestGraphTargetFactories: [Swift::String: ManifestGraph.Kind] = [
    "target": .regular,
    "macro": .macro,
    "executableTarget": .executable,
    "testTarget": .test,
    "systemLibrary": .other,
    "binaryTarget": .other,
    "plugin": .other,
]

internal final class ManifestGraphVisitor: SyntaxVisitor {
    var graph = ManifestGraph()
    var unhandledSourceShape: Swift::String?
    private var stringStaticAccessorBodies: [Swift::String: ExprSyntax] = [:]
    private var stringInstanceAccessorBodies: [Swift::String: ExprSyntax] = [:]
    private var dependencyAccessorBodies: [Swift::String: ExprSyntax] = [:]

    override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    convenience init(accessorsOf file: SourceFileSyntax) {
        self.init(viewMode: .sourceAccurate)
        let stringTypes: Swift::Set<Swift::String> = ["String", "Swift.String"]
        stringStaticAccessorBodies = manifestAccessorBodies(in: file, extendedTypes: stringTypes, static: true)
        stringInstanceAccessorBodies = manifestAccessorBodies(in: file, extendedTypes: stringTypes, static: false)
        dependencyAccessorBodies = manifestAccessorBodies(
            in: file,
            extendedTypes: ["Target.Dependency", "PackageDescription.Target.Dependency"],
            static: true
        )
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package" {
            if let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }) {
                graph.name = resolved(nameArgument.expression)
                graph.namePosition = nameArgument.expression.positionAfterSkippingLeadingTrivia
            }
            if let traits = node.arguments.first(where: { $0.label?.text == "traits" })?.expression.as(ArrayExprSyntax.self) {
                graph.traits = traits.elements.compactMap { trait($0.expression) }
            }
        }
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            !isNestedInsideDependenciesArgument(Syntax(node))
        else { return .visitChildren }
        let calleeName = member.declName.baseName.text
        if calleeName == "library" {
            recordProduct(node)
        } else if let kind = manifestGraphTargetFactories[calleeName] {
            recordTarget(node, kind: kind)
        }
        return .visitChildren
    }

    /// A declared trait's name. A name that cannot be read leaves the trait out rather than the manifest unmeasured.
}

extension ManifestGraphVisitor {
    private func trait(_ expression: ExprSyntax) -> Swift::String? {
        if expression.is(StringLiteralExprSyntax.self) { return quietlyResolved(expression) }
        guard let call = expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "trait",
            let name = call.arguments.first(where: { $0.label?.text == "name" })
        else { return nil }
        return quietlyResolved(name.expression)
    }

    private func quietlyResolved(_ expression: ExprSyntax) -> Swift::String? {
        var ignored: Swift::String?
        return manifestResolvedString(
            expression,
            staticAccessors: stringStaticAccessorBodies,
            instanceAccessors: stringInstanceAccessorBodies,
            unhandledSourceShape: &ignored
        )
    }

    private func isNestedInsideDependenciesArgument(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let labeled = candidate.as(LabeledExprSyntax.self), labeled.label?.text == "dependencies" {
                return true
            }
            current = candidate.parent
        }
        return false
    }

    private func resolved(_ expression: ExprSyntax) -> Swift::String? {
        manifestResolvedString(
            expression,
            staticAccessors: stringStaticAccessorBodies,
            instanceAccessors: stringInstanceAccessorBodies,
            unhandledSourceShape: &unhandledSourceShape
        )
    }

    private func recordProduct(_ node: FunctionCallExprSyntax) {
        guard let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }),
            let name = resolved(nameArgument.expression),
            let targetsArgument = node.arguments.first(where: { $0.label?.text == "targets" })
        else { return }
        guard let array = targetsArgument.expression.as(ArrayExprSyntax.self) else {
            unhandledSourceShape =
                unhandledSourceShape
                ?? "computed product targets '\(targetsArgument.expression.trimmedDescription)'"
            return
        }
        graph.products.append(
            .init(
                name: name,
                targets: array.elements.compactMap { resolved($0.expression) },
                position: nameArgument.expression.positionAfterSkippingLeadingTrivia
            )
        )
    }

    private func recordTarget(_ node: FunctionCallExprSyntax, kind: ManifestGraph.Kind) {
        guard let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }),
            let name = resolved(nameArgument.expression)
        else { return }
        var edges: [ManifestGraph.Edge] = []
        for argument in node.arguments where argument.label?.text == "dependencies" && kind != .test {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                unhandledSourceShape =
                    unhandledSourceShape
                    ?? "computed target dependencies '\(argument.expression.trimmedDescription)'"
                continue
            }
            for element in array.elements {
                edges += self.edges(element.expression, visited: [])
            }
        }
        let path = node.arguments.first(where: { $0.label?.text == "path" })
            .flatMap { $0.expression.as(StringLiteralExprSyntax.self) }
            .flatMap(manifestStringLiteralText)
        graph.targets.append(
            .init(
                name: name,
                kind: kind,
                path: path,
                position: nameArgument.expression.positionAfterSkippingLeadingTrivia,
                edges: edges
            )
        )
    }

    private func edges(_ expression: ExprSyntax, visited: Swift::Set<Swift::String>) -> [ManifestGraph.Edge] {
        let position = expression.positionAfterSkippingLeadingTrivia
        if let literal = expression.as(StringLiteralExprSyntax.self) {
            guard let text = manifestStringLiteralText(literal) else {
                unhandledSourceShape =
                    unhandledSourceShape ?? "interpolated target dependency '\(expression.trimmedDescription)'"
                return []
            }
            return [.init(reference: .target(text), traits: [], position: position)]
        }
        if let call = expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self)
        {
            let traits = call.arguments.first(where: { $0.label?.text == "condition" }).map { conditionTraits($0.expression) } ?? []
            switch member.declName.baseName.text {
            case "target", "byName":
                guard
                    let nameArgument = call.arguments.first(where: { $0.label?.text == "name" || $0.label == nil }),
                    let name = resolved(nameArgument.expression)
                else { return [] }
                return [.init(reference: .target(name), traits: traits, position: position)]
            case "product":
                guard
                    let nameArgument = call.arguments.first(where: { $0.label?.text == "name" }),
                    let name = resolved(nameArgument.expression)
                else { return [] }
                let package =
                    call.arguments.first(where: { $0.label?.text == "package" }).flatMap { resolved($0.expression) } ?? name
                return [.init(reference: .product(name, package: package), traits: traits, position: position)]
            default:
                break
            }
        }
        if let member = expression.as(MemberAccessExprSyntax.self), member.base == nil {
            let name = member.declName.baseName.text
            guard !visited.contains(name), let body = dependencyAccessorBodies[name] else {
                unhandledSourceShape = unhandledSourceShape ?? "unresolved target dependency accessor '\(name)'"
                return []
            }
            return edges(body, visited: visited.union([name]))
        }
        unhandledSourceShape =
            unhandledSourceShape ?? "unhandled target dependency '\(expression.trimmedDescription)'"
        return []
    }

    private func conditionTraits(_ expression: ExprSyntax) -> [Swift::String] {
        guard let call = expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "when",
            let traits = call.arguments.first(where: { $0.label?.text == "traits" })?.expression.as(ArrayExprSyntax.self)
        else { return [] }
        return traits.elements.compactMap { quietlyResolved($0.expression) }
    }
}
