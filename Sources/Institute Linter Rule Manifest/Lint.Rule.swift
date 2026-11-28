public import Lint
internal import Package
internal import SwiftSyntax

extension Lint.Rule {
    /// I7: in a package with a primary target, a target outside the primary target's closure takes a product from a
    /// package the closure does not reach only under a trait condition, one trait per such target, named for the
    /// peer when the target is glue to one package. A macro's declarations, its macro target and its implementation
    /// share one trait. While swift-institute/Issues#123 is open, a target whose source is gated by that trait meets
    /// the rule with an unconditional product dependency. Not judged here: that a trait of a target that is glue to
    /// several packages, or to none, is named for the target's role.
    public static let `untraited partial dependency` = Lint.Rule(
        id: "untraited partial dependency",
        default: .warning,
        controls: [
            .init(
                id: "untraited partial dependency one of two products",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Glob\", package: \"swift-glob\")])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "untraited partial dependency trait gated",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], traits: ["
                    + ".trait(name: \"Glob\")], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Glob\", package: \"swift-glob\", "
                    + "condition: .when(traits: [\"Glob\"]))])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency shared core",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner Core\", dependencies: [.product(name: \"Span\", package: \"swift-span\")]), "
                    + ".target(name: \"Owner\", dependencies: [.target(name: \"Owner Core\")]), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner Core\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency test support reaching only the primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\", dependencies: [.product(name: \"Span\", package: \"swift-span\")]), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency test support is judged",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Testing Support\", package: \"swift-testing-support\")])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "untraited partial dependency primary target needs it",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Core\", targets: [\"Owner Core\"])], targets: ["
                    + ".target(name: \"Owner Core\"), "
                    + ".target(name: \"Owner\", dependencies: [.target(name: \"Owner Core\"), "
                    + ".product(name: \"Span\", package: \"swift-span\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency no primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner Kernel\", targets: [\"Owner Kernel\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner Kernel\"), "
                    + ".target(name: \"Owner Glob\", dependencies: ["
                    + ".product(name: \"Glob\", package: \"swift-glob\")])])",
                path: "Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
            .init(
                id: "untraited partial dependency outside manifest",
                source: "let dependency = Target.Dependency.product(name: \"Glob\", package: \"swift-glob\")",
                path: "Sources/Fixture/Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            guard graph.primaryTarget != nil else {
                return Lint.Rule.Observation(findings: [], coverage: coverage, applicability: .inapplicable)
            }
            let sources = ManifestPackageSources.of(source)
            let findings = manifestUntraitedPartialDependencyFindings(
                graph,
                gate: { target in
                    manifestTargetSourceGate(target, in: sources)
                }
            ).map { finding in
                let location = source.converter.location(for: finding.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "untraited partial dependency",
                    message: finding.message
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

extension Lint.Rule {
    /// I4, first half: a library's root package has a regular target whose name claims the concept the package's
    /// name claims, and a library product of that name.
    public static let `no primary target` = Lint.Rule(
        id: "no primary target",
        default: .warning,
        controls: [
            .init(
                id: "no primary target product holds a target of another name",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner Kernel\"])], targets: ["
                    + ".target(name: \"Owner Kernel\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "no primary target primary target without a product",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner\"), .target(name: \"Owner Glob\", dependencies: [\"Owner\"])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "no primary target only a macro product",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner Macro\", targets: [\"Owner Macro\"])], targets: ["
                    + ".target(name: \"Owner Macro\", dependencies: [\"Owner Macro Plugin\"]), "
                    + ".macro(name: \"Owner Macro Plugin\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "no primary target primary product and target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"])], targets: [.target(name: \"Owner\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "no primary target no library",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".executable(name: \"owner\", targets: [\"Owner CLI\"])], targets: ["
                    + ".executableTarget(name: \"Owner CLI\")])",
                path: "Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
            .init(
                id: "no primary target nested package",
                source: "let package = Package(name: \"fixture\", products: ["
                    + ".library(name: \"Fixture Kernel\", targets: [\"Fixture Kernel\"])], targets: ["
                    + ".target(name: \"Fixture Kernel\")])",
                path: "Tests/Fixtures/Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsRootManifest(source),
                manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description)
            else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            guard !graph.products.isEmpty, let name = graph.name, let position = graph.namePosition else {
                return Lint.Rule.Observation(findings: [], coverage: coverage, applicability: .inapplicable)
            }
            guard let message = manifestNoPrimaryTargetMessage(graph, package: name) else {
                return Lint.Rule.Observation(findings: [], coverage: coverage)
            }
            let location = source.converter.location(for: position)
            let finding = Diagnostic.Record(
                location: Source.Location(
                    fileID: source.file.fileID,
                    filePath: source.file.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "no primary target",
                message: message
            )
            return Lint.Rule.Observation(findings: [finding], coverage: coverage)
        }
    )
}

extension Lint.Rule {
    /// I4, second half: a library product that is not the primary product is named `<Primary> <Role>`. Asked only
    /// where a primary product exists.
    public static let `product name` = Lint.Rule(
        id: "product name",
        default: .warning,
        controls: [
            .init(
                id: "product name without the primary name",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Glob Support\", targets: [\"Glob Support\"])], targets: ["
                    + ".target(name: \"Owner\"), .target(name: \"Glob Support\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "product name primary and role",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\"), .target(name: \"Owner Glob\"), .target(name: \"Owner Test Support\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "product name glued to the primary name",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"OwnerGlob\", targets: [\"OwnerGlob\"])], targets: ["
                    + ".target(name: \"Owner\"), .target(name: \"OwnerGlob\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "product name without a primary product",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner Kernel\", targets: [\"Owner Kernel\"]), "
                    + ".library(name: \"Glob Support\", targets: [\"Glob Support\"])], targets: ["
                    + ".target(name: \"Owner Kernel\"), .target(name: \"Glob Support\")])",
                path: "Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsRootManifest(source),
                manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description)
            else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            guard let primary = graph.primaryProduct else {
                return Lint.Rule.Observation(findings: [], coverage: coverage, applicability: .inapplicable)
            }
            let findings = graph.products.filter { product in
                product.name != primary.name && !(product.name.hasPrefix(primary.name + " ") && product.name.count > primary.name.count + 1)
            }.map { product in
                let location = source.converter.location(for: product.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "product name",
                    message: "[product name] [I4]: a library product that is not the primary product is named "
                        + "`<Primary> <Role>`. `\(product.name)` does not begin with `\(primary.name) `; name it "
                        + "`\(primary.name)` and its role in words."
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

extension Lint.Rule {
    /// A regular target named `<X> Primitive`, `<X> Core`, `<X> Shared`, `<X> Protocol` or `<X> Namespace` is a stratum
    /// when `<X>` claims the concept of the package, of another of its targets, or of a public type or typealias the
    /// package declares. A stratum is a position in a stack, not a role, and is never a target: it folds into the
    /// target it is a stratum of, also when a product exposes it. A macro's implementation target folds into its
    /// macro target.
    public static let `stratum target` = Lint.Rule(
        id: "stratum target",
        default: .warning,
        controls: [
            .init(
                id: "stratum target core of the primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Core\", targets: [\"Owner Core\"])], targets: ["
                    + ".target(name: \"Owner Core\"), .target(name: \"Owner\", dependencies: [\"Owner Core\"])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "stratum target a part's own name",
                source: "let package = Package(name: \"swift-sigma\", products: ["
                    + ".library(name: \"Sigma\", targets: [\"Sigma\"]), "
                    + ".library(name: \"Sigma Dublin Core\", targets: [\"Sigma Dublin Core\"])], targets: ["
                    + ".target(name: \"Sigma\"), .target(name: \"Sigma Dublin Core\", dependencies: [\"Sigma\"])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "stratum target macro implementation",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"])], targets: ["
                    + ".target(name: \"Owner\", dependencies: [\"Owner Macro\"]), "
                    + ".macro(name: \"Owner Macro\", dependencies: [\"Owner Macro Core\"]), "
                    + ".target(name: \"Owner Macro Core\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "stratum target outside manifest",
                source: "let target = Target.target(name: \"Owner Core\")",
                path: "Sources/Fixture/Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description)
            else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            var types: [Package.Concept: [Swift::String]] = [:]
            if let sources = ManifestPackageSources.of(source) {
                for (path, facts) in sources.facts {
                    for declaration in facts.declarations where declaration.isPublic && declaration.kind != .macro {
                        let owner = sources.target(containing: path)?.name ?? ""
                        types[Package.Concept(type: declaration.path), default: []].append(owner)
                    }
                }
            }
            let findings = manifestStratumTargetFindings(graph, types: types).map { finding in
                let location = source.converter.location(for: finding.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "stratum target",
                    message: finding.message
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}
