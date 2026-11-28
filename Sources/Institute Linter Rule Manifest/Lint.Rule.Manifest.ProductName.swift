public import Lint
internal import SwiftSyntax

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
