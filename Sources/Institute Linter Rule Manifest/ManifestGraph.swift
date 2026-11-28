internal import Lint
package import Package
package import SwiftSyntax

/// What a package manifest declares that the target and product rules read: its name, its library products, its
/// traits and its targets with their edges. Strings that typed manifest accessors spell (`.owner` for `"Owner"`)
/// are resolved; a shape that cannot be read is named in `unhandledSourceShape`.
package struct ManifestGraph: Sendable {
    package var name: Swift::String?
    var namePosition: AbsolutePosition?
    package var products: [Product] = []
    package var targets: [Target] = []
    package var traits: [Swift::String] = []
    var unhandledSourceShape: Swift::String?

    package init() {}
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
    var primaryTarget: Target? {
        guard let concept else { return nil }
        return targets.first { $0.kind == .regular && Package.Concept(type: [$0.name]) == concept }
    }

    /// The library product whose name claims the concept the package's name claims.
    var primaryProduct: Product? {
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
    func macroGroup(of name: Swift::String) -> Swift::Set<Swift::String> {
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
