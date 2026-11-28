public import Lint
internal import Package
internal import SwiftSyntax

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

/// Whether `source` is the manifest at the root of the linted package, not one nested in a folder of it.
internal func manifestIsRootManifest(_ source: borrowing Lint.Source.Parsed) -> Swift::Bool {
    !source.relativePath.contains("/")
}

internal func manifestNoPrimaryTargetMessage(_ graph: ManifestGraph, package: Swift::String) -> Swift::String? {
    let statement =
        "[no primary target] [I4]: a library's root package has a regular target whose name claims the concept the "
        + "package's name claims, and a library product of that name."
    guard let primary = graph.primaryTarget else {
        let products = graph.products.map { "`\($0.name)`" }.joined(separator: ", ")
        return statement + " `\(package)` has no regular target named for it; its products are \(products). "
            + "Name the target that holds what the package's name claims for the package, and give it the product."
    }
    if let product = graph.primaryProduct, product.targets.contains(primary.name) { return nil }
    if let product = graph.primaryProduct {
        return statement + " The product `\(product.name)` does not hold the target `\(primary.name)`."
    }
    return statement + " No library product exposes `\(primary.name)`; add `.library(name: \"\(primary.name)\", "
        + "targets: [\"\(primary.name)\"])`."
}
