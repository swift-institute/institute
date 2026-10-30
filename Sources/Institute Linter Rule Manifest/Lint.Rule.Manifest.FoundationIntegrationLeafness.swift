public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `foundation integration leaf target` = Lint.Rule(
        id: "foundation integration leaf target",
        default: .warning,
        controls: [
            .init(
                id: "foundation integration leaf target missing product",
                source: "let package = Package(products: [], targets: ["
                    + ".target(name: \"Example Foundation Integration\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation integration leaf target dedicated product",
                source: "let package = Package(products: ["
                    + ".library(name: \"Example Foundation Integration\", "
                    + "targets: [\"Example Foundation Integration\"])], targets: ["
                    + ".target(name: \"Example Foundation Integration\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation integration leaf target versioned executable product",
                source: "let package = Package(products: ["
                    + ".executable(name: \"Example Foundation Integration\", "
                    + "targets: [\"Example Foundation Integration\"])], targets: ["
                    + ".executableTarget(name: \"Example Foundation Integration\")])",
                path: "Package@swift-6.4.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation integration leaf target typed manifest vocabulary",
                source: "extension String { static let css: Self = \"CSS\"; "
                    + "static let cssTheming: Self = \"CSS Theming\"; "
                    + "var tests: Self { self + \" Tests\" } }; "
                    + "extension Target.Dependency { static var cssTheming: Self { "
                    + ".target(name: .cssTheming) } }; "
                    + "let package = Package(products: ["
                    + ".library(name: \"CSS Theming Foundation Integration\", "
                    + "targets: [\"CSS Theming Foundation Integration\"])], targets: ["
                    + ".target(name: .cssTheming), "
                    + ".target(name: \"CSS Theming Foundation Integration\", "
                    + "dependencies: [.cssTheming]), "
                    + ".testTarget(name: .css.tests, dependencies: [.cssTheming])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation integration leaf target tested by its own test target",
                source: "let package = Package(products: ["
                    + ".library(name: \"Example Foundation Integration\", "
                    + "targets: [\"Example Foundation Integration\"])], targets: ["
                    + ".target(name: \"Example Foundation Integration\"), "
                    + ".testTarget(name: \"Example Foundation Integration Tests\", "
                    + "dependencies: [\"Example Foundation Integration\"])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "foundation integration leaf target depended on by a library target",
                source: "let package = Package(products: ["
                    + ".library(name: \"Example Foundation Integration\", "
                    + "targets: [\"Example Foundation Integration\"])], targets: ["
                    + ".target(name: \"Example Foundation Integration\"), "
                    + ".target(name: \"Example\", dependencies: [\"Example Foundation Integration\"]), "
                    + ".testTarget(name: \"Example Tests\", dependencies: [\"Example\"])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "foundation integration leaf target typed name missing product",
                source: "extension String { static let integration: Self = "
                    + "\"Example Foundation Integration\" }; "
                    + "let package = Package(products: [], targets: ["
                    + ".target(name: .integration)])",
                path: "Package.swift",
                expectation: .findings(1)
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
            let visitor = ManifestFoundationIntegrationLeafnessVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.collectManifestAccessors(source.tree)
            visitor.walk(source.tree)
            let findings = visitor.resolvedMatches()
            let coverage: Lint.Rule.Coverage =
                visitor.unhandledSourceShape.map {
                    .unmeasured(.unsupportedSourceShape($0))
                } ?? .measured
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

private let manifestFoundationIntegrationLeafnessMessage: Swift::String =
    "[foundation integration leaf target]: a target named `* Foundation "
    + "Integration` must be a LEAF — declared as a `.library` or `.executable` product "
    + "of "
    + "its own, and depended on by no other target. A name-based "
    + "exclusion (the Tier 2 SwiftLint carve-out) grants the "
    + "Foundation-freedom exception on the name alone and cannot see "
    + "this. Either declare a dedicated `.library` or `.executable` product exposing "
    + "only "
    + "this target, or remove it from whichever other target's "
    + "`dependencies:` still lists it (per "
    + "swift-structured-queries#2)."

private let manifestFoundationIntegrationTargetFactories: Swift::Set<Swift::String> = [
    "target", "testTarget", "executableTarget", "macro", "plugin",
]

private let manifestFoundationIntegrationSuffix = " Foundation Integration"

internal final class ManifestFoundationIntegrationLeafnessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    private var matches: [Diagnostic.Record] = []

    private struct FoundationIntegrationTarget {
        let name: Swift::String
        let position: AbsolutePosition
    }
    private var foundationIntegrationTargets: [FoundationIntegrationTarget] = []

    private var dependencyEdgesByDepender: [Swift::String: Swift::Set<Swift::String>] = [:]

    private var leafProductTargetLists: [[Swift::String]] = []
    var unhandledSourceShape: Swift::String?
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
        stringStaticAccessorBodies = manifestAccessorBodies(
            in: file,
            extendedTypes: stringTypes,
            static: true
        )
        stringInstanceAccessorBodies = manifestAccessorBodies(
            in: file,
            extendedTypes: stringTypes,
            static: false
        )
        dependencyAccessorBodies = manifestAccessorBodies(
            in: file,
            extendedTypes: ["Target.Dependency", "PackageDescription.Target.Dependency"],
            static: true
        )
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        let calleeName = member.declName.baseName.text
        if calleeName == "library" || calleeName == "executable" {
            recordLeafProduct(node)
        } else if manifestFoundationIntegrationTargetFactories.contains(calleeName),
            !isNestedInsideDependenciesArgument(Syntax(node))
        {
            recordTargetDecl(node)
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

    private func recordLeafProduct(_ node: FunctionCallExprSyntax) {
        for argument in node.arguments where argument.label?.text == "targets" {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                unhandledSourceShape =
                    "computed product targets '\(argument.expression.trimmedDescription)'"
                continue
            }
            var names: [Swift::String] = []
            for element in array.elements {
                guard
                    let text = manifestResolvedString(
                        element.expression,
                        staticAccessors: stringStaticAccessorBodies,
                        instanceAccessors: stringInstanceAccessorBodies,
                        unhandledSourceShape: &unhandledSourceShape
                    )
                else { continue }
                names.append(text)
            }
            leafProductTargetLists.append(names)
        }
    }

    private func recordTargetDecl(_ node: FunctionCallExprSyntax) {
        guard
            let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }),
            let name = manifestResolvedString(
                nameArgument.expression,
                staticAccessors: stringStaticAccessorBodies,
                instanceAccessors: stringInstanceAccessorBodies,
                unhandledSourceShape: &unhandledSourceShape
            )
        else { return }

        if name.hasSuffix(manifestFoundationIntegrationSuffix) {
            foundationIntegrationTargets.append(
                FoundationIntegrationTarget(
                    name: name,
                    position: nameArgument.expression.positionAfterSkippingLeadingTrivia
                )
            )
        }

        var referenced: Swift::Set<Swift::String> = []
        for argument in node.arguments where argument.label?.text == "dependencies" {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                unhandledSourceShape =
                    "computed target dependencies '\(argument.expression.trimmedDescription)'"
                continue
            }
            for element in array.elements {
                let resolution = manifestFoundationIntegrationDependency(
                    element.expression,
                    dependencyAccessorBodies: dependencyAccessorBodies,
                    stringStaticAccessors: stringStaticAccessorBodies,
                    stringInstanceAccessors: stringInstanceAccessorBodies,
                    unhandledSourceShape: &unhandledSourceShape
                )
                guard resolution.handled else { continue }
                if let target = resolution.localTarget {
                    referenced.insert(target)
                }
            }
        }
        let isTestTarget =
            node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "testTarget"
        guard !isTestTarget else { return }
        dependencyEdgesByDepender[name, default: []].formUnion(referenced)
    }

    internal func resolvedMatches() -> [Diagnostic.Record] {
        for target in foundationIntegrationTargets {
            let isLeafProduct = leafProductTargetLists.contains { $0 == [target.name] }
            let hasIncomingEdge = dependencyEdgesByDepender.contains { depender, referenced in
                depender != target.name && referenced.contains(target.name)
            }
            guard !isLeafProduct || hasIncomingEdge else { continue }
            let location = converter.location(for: target.position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "foundation integration leaf target",
                    message: manifestFoundationIntegrationLeafnessMessage
                )
            )
        }
        return matches
    }
}

private func manifestFoundationIntegrationDependency(
    _ expression: ExprSyntax,
    dependencyAccessorBodies: [Swift::String: ExprSyntax],
    stringStaticAccessors: [Swift::String: ExprSyntax],
    stringInstanceAccessors: [Swift::String: ExprSyntax],
    visited: Swift::Set<Swift::String> = [],
    unhandledSourceShape: inout Swift::String?
) -> (handled: Swift::Bool, localTarget: Swift::String?) {
    if let literal = expression.as(StringLiteralExprSyntax.self) {
        guard let text = manifestStringLiteralText(literal) else {
            unhandledSourceShape =
                unhandledSourceShape ?? "interpolated target dependency '\(expression.trimmedDescription)'"
            return (false, nil)
        }
        return (true, text)
    }

    if let call = expression.as(FunctionCallExprSyntax.self),
        let member = call.calledExpression.as(MemberAccessExprSyntax.self)
    {
        switch member.declName.baseName.text {
        case "target", "byName":
            guard
                let nameArgument = call.arguments.first(where: {
                    $0.label?.text == "name" || $0.label == nil
                }),
                let name = manifestResolvedString(
                    nameArgument.expression,
                    staticAccessors: stringStaticAccessors,
                    instanceAccessors: stringInstanceAccessors,
                    unhandledSourceShape: &unhandledSourceShape
                )
            else { return (false, nil) }
            return (true, name)
        case "product", "plugin":
            return (true, nil)
        default:
            break
        }
    }

    if let member = expression.as(MemberAccessExprSyntax.self), member.base == nil {
        let name = member.declName.baseName.text
        guard !visited.contains(name), let body = dependencyAccessorBodies[name] else {
            unhandledSourceShape =
                unhandledSourceShape ?? "unresolved target dependency accessor '\(name)'"
            return (false, nil)
        }
        return manifestFoundationIntegrationDependency(
            body,
            dependencyAccessorBodies: dependencyAccessorBodies,
            stringStaticAccessors: stringStaticAccessors,
            stringInstanceAccessors: stringInstanceAccessors,
            visited: visited.union([name]),
            unhandledSourceShape: &unhandledSourceShape
        )
    }

    unhandledSourceShape =
        unhandledSourceShape
        ?? "unhandled target dependency '\(expression.trimmedDescription)'"
    return (false, nil)
}
