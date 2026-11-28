internal import Lint
internal import Package
internal import SwiftSyntax

internal let manifestUntraitedPartialDependencyStatement: Swift::String =
    "[untraited partial dependency] [I7]: in a package with a primary target, a target outside the primary "
    + "target's closure takes a product from a package the closure does not reach only under a trait condition, "
    + "one trait per such target, named for the peer when the target is glue to one package."

/// The identifiers that gate every file of `target` that has content, or nil when a file is not gated, the target
/// has no file with content, or the package is not on disk.
internal func manifestTargetSourceGate(
    _ target: Swift::String,
    in sources: ManifestPackageSources?
) -> Swift::Set<Swift::String>? {
    guard let sources, let files = sources.files[target] else { return nil }
    var gates: Swift::Set<Swift::String>?
    for file in files {
        switch sources.facts[file]?.gate {
        case .gated(let identifiers)?: gates = (gates ?? identifiers).intersection(identifiers)
        case .none?: continue
        case .open?, nil: return nil
        }
    }
    return gates
}

/// The findings of `untraited partial dependency` in `graph`, which has a primary target. `gate` gives the
/// identifiers that gate a target's whole source.
internal func manifestUntraitedPartialDependencyFindings(
    _ graph: ManifestGraph,
    gate: (Swift::String) -> Swift::Set<Swift::String>?
) -> [(position: AbsolutePosition, message: Swift::String)] {
    guard let primary = graph.primaryTarget else { return [] }
    let closure = graph.closure(of: primary.name)
    let reached = graph.packages(reachedBy: closure)
    let declaredTraits = Swift::Set(graph.traits)
    var findings: [(position: AbsolutePosition, message: Swift::String)] = []
    var traitUsers: [Swift::String: [Swift::String]] = [:]
    for target in graph.targets where target.kind == .regular || target.kind == .macro {
        guard !closure.contains(target.name) else { continue }
        var foreign: [(package: Swift::String, product: Swift::String, edge: ManifestGraph.Edge)] = []
        for edge in target.edges {
            guard case .product(let product, let package) = edge.reference, !reached.contains(package) else { continue }
            foreign.append((package, product, edge))
        }
        guard !foreign.isEmpty else { continue }
        let sourceGate = gate(target.name)?.intersection(declaredTraits) ?? []
        var reported: Swift::Set<Swift::String> = []
        for use in foreign where !use.edge.gated && sourceGate.isEmpty && reported.insert(use.package).inserted {
            findings.append(
                (
                    use.edge.position,
                    manifestUntraitedPartialDependencyStatement
                        + " `\(target.name)` takes `\(use.package)` without one, and `\(primary.name)` and the targets "
                        + "it reaches do not take `\(use.package)`; gate it with `condition: .when(traits: [...])`, or, "
                        + "while swift-institute/Issues#123 is open, gate the target's source with `#if` that trait. "
                        + "SwiftPM ignores the product filter (`ENABLE_TARGET_BASED_DEPENDENCY_RESOLUTION` is compiled "
                        + "out in `Manifest.dependenciesRequired`), so every consumer of any product of this package "
                        + "resolves and loads the dependency; only a trait condition that is switched off keeps it out "
                        + "of the graph."
                )
            )
        }
        let traits = Swift::Set(foreign.flatMap { $0.edge.traits }).union(sourceGate).sorted()
        if traits.count > 1 {
            findings.append(
                (
                    target.position,
                    manifestUntraitedPartialDependencyStatement
                        + " `\(target.name)` is gated by " + traits.map { "`\($0)`" }.joined(separator: ", ")
                        + "; one trait gates one target."
                )
            )
        }
        let peers = Swift::Set(foreign.map { $0.package })
        if traits.count == 1, let trait = traits.first, peers.count == 1, let peer = peers.first {
            let named =
                Package.Concept(type: [trait]) == Package.Concept(Package.Name(_unchecked: peer))
                || foreign.contains { Package.Concept(type: [$0.product]) == Package.Concept(type: [trait]) }
            if !named {
                findings.append(
                    (
                        target.position,
                        manifestUntraitedPartialDependencyStatement
                            + " `\(target.name)` is glue to `\(peer)` alone, so its trait is named for `\(peer)`, "
                            + "not `\(trait)`."
                    )
                )
            }
        }
        for trait in traits {
            if let other = traitUsers[trait]?.first(where: { !graph.macroGroup(of: target.name).contains($0) }) {
                findings.append(
                    (
                        target.position,
                        manifestUntraitedPartialDependencyStatement
                            + " `\(target.name)` and `\(other)` share the trait `\(trait)`; one trait gates one target, "
                            + "and only a macro's declarations, its macro target and its implementation share one."
                    )
                )
            }
            traitUsers[trait, default: []].append(target.name)
        }
    }
    return findings
}
