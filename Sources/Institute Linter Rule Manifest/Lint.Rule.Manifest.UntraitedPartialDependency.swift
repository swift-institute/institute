public import Lint
internal import SwiftSyntax

extension Lint.Rule {
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
                id: "untraited partial dependency single main product",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\", dependencies: [.product(name: \"Span\", package: \"swift-span\")]), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\")])])",
                path: "Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
            .init(
                id: "untraited partial dependency test support only",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner\")]), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Testing Support\", package: \"swift-testing-support\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency primary product needs it",
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
                id: "untraited partial dependency no primary product",
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
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: .measured,
                    applicability: .inapplicable
                )
            }
            let visitor = ManifestUntraitedPartialDependencyVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.collectManifestAccessors(source.tree)
            visitor.walk(source.tree)
            let coverage: Lint.Rule.Coverage =
                visitor.unhandledSourceShape.map {
                    .unmeasured(.unsupportedSourceShape($0))
                } ?? .measured
            guard let findings = visitor.resolvedMatches() else {
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: coverage,
                    applicability: .inapplicable
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

internal func manifestUntraitedPartialDependencyMessage(
    _ dependency: Swift::String,
    needing: [Swift::String],
    notNeeding: [Swift::String]
) -> Swift::String {
    "[untraited partial dependency] [PACKAGE-TRAIT-GATED-DEPENDENCY]: `\(dependency)` is needed by "
        + needing.map { "`\($0)`" }.joined(separator: ", ")
        + " but not by "
        + notNeeding.map { "`\($0)`" }.joined(separator: ", ")
        + "; gate its uses with `condition: .when(traits: [...])`. SwiftPM ignores the "
        + "product filter (`ENABLE_TARGET_BASED_DEPENDENCY_RESOLUTION` is compiled out in "
        + "`Manifest.dependenciesRequired`), so every consumer of any product of this package "
        + "resolves and loads the dependency; only a trait condition that is switched off "
        + "keeps it out of the graph."
}

internal let manifestUntraitedPartialDependencyExemptSuffixes: [Swift::String] = [
    " Test Support",
    " Foundation Integration",
]

private let manifestUntraitedPartialDependencyTargetFactories: Swift::Set<Swift::String> = [
    "target", "executableTarget", "macro", "systemLibrary", "binaryTarget",
]

internal final class ManifestUntraitedPartialDependencyVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var unhandledSourceShape: Swift::String?

    private enum Edge {
        case named(Swift::String, gated: Swift::Bool, position: AbsolutePosition)
        case product(Swift::String, package: Swift::String, gated: Swift::Bool, position: AbsolutePosition)
    }

    private var packageName: Swift::String?
    private var products: [(name: Swift::String, targets: [Swift::String])] = []
    private var edgesByTarget: [Swift::String: [Edge]] = [:]
    private var stringStaticAccessorBodies: [Swift::String: ExprSyntax] = [:]
    private var stringInstanceAccessorBodies: [Swift::String: ExprSyntax] = [:]
    private var dependencyAccessorBodies: [Swift::String: ExprSyntax] = [:]

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    internal func collectManifestAccessors(_ file: SourceFileSyntax) {
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
        if node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package",
            let nameArgument = node.arguments.first(where: { $0.label?.text == "name" })
        {
            packageName = resolved(nameArgument.expression)
        }
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            !isNestedInsideDependenciesArgument(Syntax(node))
        else { return .visitChildren }
        let calleeName = member.declName.baseName.text
        if calleeName == "library" {
            recordProduct(node)
        } else if manifestUntraitedPartialDependencyTargetFactories.contains(calleeName) {
            recordTarget(node)
        }
        return .visitChildren
    }

    private func isNestedInsideDependenciesArgument(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let labeled = candidate.as(LabeledExprSyntax.self),
                labeled.label?.text == "dependencies"
            {
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
                unhandledSourceShape ?? "computed product targets '\(targetsArgument.expression.trimmedDescription)'"
            return
        }
        products.append((name, array.elements.compactMap { resolved($0.expression) }))
    }

    private func recordTarget(_ node: FunctionCallExprSyntax) {
        guard let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }),
            let name = resolved(nameArgument.expression)
        else { return }
        var edges: [Edge] = []
        for argument in node.arguments where argument.label?.text == "dependencies" {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                unhandledSourceShape =
                    unhandledSourceShape ?? "computed target dependencies '\(argument.expression.trimmedDescription)'"
                continue
            }
            for element in array.elements {
                edges += self.edges(element.expression, visited: [])
            }
        }
        edgesByTarget[name, default: []] += edges
    }

    private func edges(_ expression: ExprSyntax, visited: Swift::Set<Swift::String>) -> [Edge] {
        let position = expression.positionAfterSkippingLeadingTrivia
        if let literal = expression.as(StringLiteralExprSyntax.self) {
            guard let text = manifestStringLiteralText(literal) else {
                unhandledSourceShape =
                    unhandledSourceShape ?? "interpolated target dependency '\(expression.trimmedDescription)'"
                return []
            }
            return [.named(text, gated: false, position: position)]
        }
        if let call = expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self)
        {
            let gated = call.arguments.contains { argument in
                argument.label?.text == "condition" && manifestConditionNamesTraits(argument.expression)
            }
            switch member.declName.baseName.text {
            case "target", "byName":
                guard
                    let nameArgument = call.arguments.first(where: { $0.label?.text == "name" || $0.label == nil }),
                    let name = resolved(nameArgument.expression)
                else { return [] }
                return [.named(name, gated: gated, position: position)]
            case "product":
                guard
                    let nameArgument = call.arguments.first(where: { $0.label?.text == "name" }),
                    let name = resolved(nameArgument.expression)
                else { return [] }
                let package =
                    call.arguments.first(where: { $0.label?.text == "package" })
                    .flatMap { resolved($0.expression) } ?? name
                return [.product(name, package: package, gated: gated, position: position)]
            default:
                break
            }
        }
        if let member = expression.as(MemberAccessExprSyntax.self), member.base == nil {
            let name = member.declName.baseName.text
            guard !visited.contains(name), let body = dependencyAccessorBodies[name] else {
                unhandledSourceShape =
                    unhandledSourceShape ?? "unresolved target dependency accessor '\(name)'"
                return []
            }
            return edges(body, visited: visited.union([name]))
        }
        unhandledSourceShape =
            unhandledSourceShape ?? "unhandled target dependency '\(expression.trimmedDescription)'"
        return []
    }

    /// The findings, or nil when the package has fewer than two main products or no primary
    /// product: the main product named after the package (`swift-kernel` → `Kernel`), compared
    /// without case, spaces or hyphens. A dependency the primary product needs is the package's
    /// own; gating it would make nearly every consumer opt back in. Only what the primary product
    /// can do without is optional.
    internal func resolvedMatches() -> [Diagnostic.Record]? {
        let mainProducts = products.filter { product in
            !manifestUntraitedPartialDependencyExemptSuffixes.contains(where: product.name.hasSuffix)
        }
        guard mainProducts.count >= 2,
            let packageName = self.packageName,
            let primary = mainProducts.first(where: {
                manifestUntraitedPartialDependencyFolded($0.name)
                    == manifestUntraitedPartialDependencyFolded(packageName, droppingPrefix: "swift-")
            })
        else { return nil }

        // Per dependency: the main products whose closure uses it without a
        // trait condition, and the first such use.
        var needing: [Swift::String: Swift::Set<Swift::String>] = [:]
        var firstUse: [Swift::String: AbsolutePosition] = [:]
        for product in mainProducts {
            var stack = product.targets
            var seen: Swift::Set<Swift::String> = []
            while let target = stack.popLast() {
                guard seen.insert(target).inserted,
                    !manifestUntraitedPartialDependencyExemptSuffixes.contains(where: target.hasSuffix)
                else { continue }
                for edge in edgesByTarget[target] ?? [] {
                    switch edge {
                    case .named(let name, let gated, let position):
                        if edgesByTarget[name] != nil {
                            stack.append(name)
                        } else if !gated {
                            needing[name, default: []].insert(product.name)
                            firstUse[name] = min(firstUse[name] ?? position, position)
                        }
                    case .product(_, let package, let gated, let position):
                        guard !gated else { continue }
                        needing[package, default: []].insert(product.name)
                        firstUse[package] = min(firstUse[package] ?? position, position)
                    }
                }
            }
        }

        let mainNames = mainProducts.map(\.name)
        let partial = firstUse.filter { !(needing[$0.key]?.contains(primary.name) ?? false) }
        return partial.sorted { $0.value < $1.value }.map { dependency, position in
            let users = needing[dependency] ?? []
            let location = converter.location(for: position)
            return Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "untraited partial dependency",
                message: manifestUntraitedPartialDependencyMessage(
                    dependency,
                    needing: mainNames.filter(users.contains),
                    notNeeding: mainNames.filter { !users.contains($0) }
                )
            )
        }
    }
}

internal func manifestUntraitedPartialDependencyFolded(
    _ name: Swift::String,
    droppingPrefix prefix: Swift::String = ""
) -> Swift::String {
    let lowered = name.lowercased()
    let stem = !prefix.isEmpty && lowered.hasPrefix(prefix) ? Swift::String(lowered.dropFirst(prefix.count)) : lowered
    return Swift::String(stem.filter { $0.isLetter || $0.isNumber })
}

private func manifestConditionNamesTraits(_ expression: ExprSyntax) -> Swift::Bool {
    guard let call = expression.as(FunctionCallExprSyntax.self),
        call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "when"
    else { return false }
    return call.arguments.contains { $0.label?.text == "traits" }
}
