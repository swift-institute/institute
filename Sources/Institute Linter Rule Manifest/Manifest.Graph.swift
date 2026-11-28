internal import Lint
package import Package
package import SwiftSyntax

/// What a package manifest declares that the target and product rules read: its name, its library products, its
/// traits and its targets with their edges. Strings that typed manifest accessors spell (`.owner` for `"Owner"`)
/// are resolved; a shape that cannot be read is named in `unhandledSourceShape`.
package struct ManifestGraph: Sendable {
    package var name: Swift::String?
    package var namePosition: AbsolutePosition?
    package var products: [Product] = []
    package var targets: [Target] = []
    package var traits: [Swift::String] = []
    package var unhandledSourceShape: Swift::String?

    package init() {}
}

extension ManifestGraph {
    package enum Kind: Sendable, Equatable {
        case regular
        case macro
        case executable
        case test
        case other
    }

    package struct Product: Sendable {
        package let name: Swift::String
        package let targets: [Swift::String]
        package let position: AbsolutePosition
    }

    package struct Target: Sendable {
        package let name: Swift::String
        package let kind: Kind
        package let path: Swift::String?
        package let position: AbsolutePosition
        package var edges: [Edge]

        /// The folder of the target's sources, relative to the package root.
        package var directory: Swift::String {
            path ?? ((kind == .test ? "Tests/" : "Sources/") + name)
        }
    }

    package struct Edge: Sendable {
        package enum Reference: Sendable, Hashable {
            case target(Swift::String)
            case product(Swift::String, package: Swift::String)
        }

        package var reference: Reference
        /// The traits the edge's condition names; empty when the edge has no trait condition.
        package let traits: [Swift::String]
        package let position: AbsolutePosition

        package var gated: Swift::Bool { !traits.isEmpty }
    }
}

extension ManifestGraph {
    /// The graph of `tree`, a manifest.
    package init(tree: SourceFileSyntax) {
        let visitor = ManifestGraphVisitor(accessorsOf: tree)
        visitor.walk(tree)
        self = visitor.graph
        self.unhandledSourceShape = visitor.unhandledSourceShape
        let names = Swift::Set(targets.map(\.name))
        for index in targets.indices {
            for edge in targets[index].edges.indices {
                guard case .target(let name) = targets[index].edges[edge].reference, !names.contains(name) else { continue }
                targets[index].edges[edge].reference = .product(name, package: name)
            }
        }
    }

    /// The concept the package's name claims, as `Package.Concept` reads it.
    package var concept: Package.Concept? {
        name.map { Package.Concept(Package.Name(_unchecked: $0)) }
    }

    package func target(named name: Swift::String) -> Target? {
        targets.first { $0.name == name }
    }

    /// The regular target whose name claims the concept the package's name claims.
    package var primaryTarget: Target? {
        guard let concept else { return nil }
        return targets.first { $0.kind == .regular && Package.Concept(type: [$0.name]) == concept }
    }

    /// The library product whose name claims the concept the package's name claims.
    package var primaryProduct: Product? {
        guard let concept else { return nil }
        return products.first { Package.Concept(type: [$0.name]) == concept }
    }

    /// `target` and every target of the package it reaches through edges without a trait condition.
    package func closure(of target: Swift::String) -> Swift::Set<Swift::String> {
        var seen: Swift::Set<Swift::String> = []
        var stack = [target]
        while let name = stack.popLast() {
            guard seen.insert(name).inserted, let target = self.target(named: name) else { continue }
            for edge in target.edges where !edge.gated {
                if case .target(let next) = edge.reference { stack.append(next) }
            }
        }
        return seen
    }

    /// The packages `targets` take a product from without a trait condition.
    package func packages(reachedBy targets: Swift::Set<Swift::String>) -> Swift::Set<Swift::String> {
        var packages: Swift::Set<Swift::String> = []
        for name in targets {
            for edge in self.target(named: name)?.edges ?? [] where !edge.gated {
                if case .product(_, let package) = edge.reference { packages.insert(package) }
            }
        }
        return packages
    }

    /// The `.macro` targets that depend on `name` directly: `name` is their implementation.
    package func macros(implementedBy name: Swift::String) -> [Swift::String] {
        targets.filter { $0.kind == .macro && $0.edges.contains { $0.reference == .target(name) } }.map(\.name)
    }

    /// The targets that share a trait with `name` under the macro clause: a `.macro` target, the targets it depends
    /// on and the targets that depend on it.
    package func macroGroup(of name: Swift::String) -> Swift::Set<Swift::String> {
        var group: Swift::Set<Swift::String> = [name]
        for macro in targets where macro.kind == .macro {
            var members: Swift::Set<Swift::String> = [macro.name]
            for edge in macro.edges {
                if case .target(let target) = edge.reference { members.insert(target) }
            }
            for target in targets where target.edges.contains(where: { $0.reference == .target(macro.name) }) {
                members.insert(target.name)
            }
            if members.contains(name) { group.formUnion(members) }
        }
        return group
    }
}

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

    private func trait(_ expression: ExprSyntax) -> Swift::String? {
        if expression.is(StringLiteralExprSyntax.self) { return resolved(expression) }
        guard let call = expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "trait",
            let name = call.arguments.first(where: { $0.label?.text == "name" })
        else { return nil }
        return resolved(name.expression)
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
        for argument in node.arguments where argument.label?.text == "dependencies" {
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
        let path = node.arguments.first(where: { $0.label?.text == "path" }).flatMap { resolved($0.expression) }
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
        return traits.elements.compactMap { resolved($0.expression) }
    }
}
