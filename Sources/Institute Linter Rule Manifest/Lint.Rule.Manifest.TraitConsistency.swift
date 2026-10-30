public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `trait consistency` = Lint.Rule(
        id: "trait consistency",
        default: .warning,
        controls: [
            .init(
                id: "trait consistency every import guarded",
                source: manifestTraitConsistencyFixture(condition: ""),
                path: "Package.swift",
                expectation: .findings(1),
                files: ["Sources/Owner/exports.swift": "#if Parser\n@_exported public import Parser\n#endif"]
            ),
            .init(
                id: "trait consistency every import guarded and conditioned",
                source: manifestTraitConsistencyFixture(condition: ", condition: .when(traits: [\"Parser\"])"),
                path: "Package.swift",
                expectation: .clean,
                files: ["Sources/Owner/exports.swift": "#if Parser\n@_exported public import Parser\n#endif"]
            ),
            .init(
                id: "trait consistency one import unguarded",
                source: manifestTraitConsistencyFixture(condition: ""),
                path: "Package.swift",
                expectation: .clean,
                files: [
                    "Sources/Owner/exports.swift": "#if Parser\n@_exported public import Parser\n#endif",
                    "Sources/Owner/Owner.swift": "import Parser",
                ]
            ),
            .init(
                id: "trait consistency conditioned import outside its guard",
                source: manifestTraitConsistencyFixture(condition: ", condition: .when(traits: [\"Parser\"])"),
                path: "Package.swift",
                expectation: .findings(1),
                files: ["Sources/Owner/Owner.swift": "import Parser"]
            ),
            .init(
                id: "trait consistency guard of an undeclared identifier",
                source: manifestTraitConsistencyFixture(condition: ""),
                path: "Package.swift",
                expectation: .clean,
                files: ["Sources/Owner/exports.swift": "#if DEBUG\nimport Parser\n#endif"]
            ),
            .init(
                id: "trait consistency outside manifest",
                source: "#if Parser\nimport Parser\n#endif",
                path: "Sources/Owner/exports.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let analysis = ManifestTraitConsistency(tree: source.tree, path: source.path.underlying, index: source.index)
            let findings = analysis.issues.map { issue in
                let location = source.converter.location(for: issue.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "trait consistency",
                    message: issue.message
                )
            }
            let coverage: Lint.Rule.Coverage =
                analysis.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        },
        repair: { source in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return .unchanged
            }
            let analysis = ManifestTraitConsistency(tree: source.tree, path: source.path.underlying, index: source.index)
            let insertions = analysis.issues.compactMap(\.insertion)
            guard insertions.count == analysis.issues.count else { return .refused(.repairUnavailable) }
            guard !insertions.isEmpty else { return .unchanged }
            var bytes = Swift::Array(source.tree.description.utf8)
            for insertion in insertions.sorted(by: { $0.offset > $1.offset }) {
                bytes.insert(contentsOf: insertion.text.utf8, at: insertion.offset)
            }
            return .edits([.rewrite(path: source.path, contents: Swift::String(decoding: bytes, as: UTF8.self))])
        }
    )
}

internal func manifestTraitConsistencyFixture(condition: Swift::String) -> Swift::String {
    "let package = Package(name: \"swift-owner\", traits: [.trait(name: \"Parser\")], "
        + "dependencies: [.package(url: \"https://github.com/swift-atoms/swift-parser.git\", branch: \"main\")], "
        + "targets: [.target(name: \"Owner\", dependencies: ["
        + ".product(name: \"Parser\", package: \"swift-parser\"\(condition))])])"
}

/// R1: a dependency whose every import in its target sits inside `#if T…`, where T is a
/// declared trait, carries `condition: .when(traits: [T…])`. R2: a dependency conditioned on
/// traits is never imported outside a guard that implies one of them.
///
/// It reads the target's imports from the package facts, so it checks the files the run
/// walked; a module the product vends under a name other than the product's is not seen.
internal struct ManifestTraitConsistency {

    struct Issue {
        let position: AbsolutePosition
        let message: Swift::String
        let insertion: (offset: Swift::Int, text: Swift::String)?
    }

    private(set) var issues: [Issue] = []

    private(set) var unhandledSourceShape: Swift::String?

    init(tree: SourceFileSyntax, path: Swift::String, index: Lint.Source.Index) {
        let collector = ManifestTraitConsistencyCollector(viewMode: .sourceAccurate)
        collector.walk(tree)
        unhandledSourceShape = collector.unhandledSourceShape
        let traits = collector.traits
        guard !traits.isEmpty else { return }
        let names = Swift::Set(traits.keys)
        let localTargets = Swift::Set(collector.targets.map(\.name))
        let directory = path.split(separator: "/").dropLast().joined(separator: "/")

        for target in collector.targets {
            let relative = (target.path ?? "\(target.defaultRoot)/\(target.name)")
                .split(separator: "/").filter { $0 != "." }.joined(separator: "/")
            let root = directory.isEmpty ? relative : directory + "/" + relative
            let imports = index.imports(under: root)
            for dependency in target.dependencies where !localTargets.contains(dependency.name) {
                let module = Swift::String(dependency.name.map { $0 == " " || $0 == "-" ? "_" : $0 })
                let uses = imports.filter { $0.import.module == module }
                guard !uses.isEmpty else { continue }
                if let conditioned = dependency.traits {
                    let allowed = names.filter { !Self.closure(of: $0, in: traits).isDisjoint(with: conditioned) }
                    for use in uses where !use.import.isGuarded(by: allowed, among: names) {
                        issues.append(
                            Issue(
                                position: dependency.position,
                                message: "[trait consistency] [PACKAGE-TRAIT-GATED-IMPORT]: `\(dependency.name)` is "
                                    + "conditioned on traits \(Self.list(conditioned)) in target `\(target.name)`, but "
                                    + "`\(use.path):\(use.import.line)` imports `\(module)` outside a guard that implies "
                                    + "one of them; with those traits off the import has no module to find.",
                                insertion: nil
                            )
                        )
                    }
                } else {
                    let guards = uses.map { $0.import.guards(among: names) }
                    guard guards.allSatisfy({ !$0.isEmpty }) else { continue }
                    let needed = guards.reduce(into: Swift::Set<Swift::String>()) { $0.formUnion($1) }
                    let condition = "condition: .when(traits: \(Self.list(needed)))"
                    issues.append(
                        Issue(
                            position: dependency.position,
                            message: "[trait consistency] [PACKAGE-TRAIT-GATED-IMPORT]: every import of "
                                + "`\(module)` in target `\(target.name)` sits inside `#if \(needed.sorted().joined(separator: "/"))`; "
                                + "add `\(condition)` so a consumer with those traits off does not resolve "
                                + "`\(dependency.name)`.",
                            insertion: dependency.insertionOffset.map { ($0, ", " + condition) }
                        )
                    )
                }
            }
        }
    }

    private static func closure(of trait: Swift::String, in traits: [Swift::String: [Swift::String]]) -> Swift::Set<Swift::String> {
        var pending = [trait]
        var seen: Swift::Set<Swift::String> = []
        while let next = pending.popLast() {
            guard seen.insert(next).inserted else { continue }
            pending.append(contentsOf: traits[next] ?? [])
        }
        return seen
    }

    private static func list(_ traits: Swift::Set<Swift::String>) -> Swift::String {
        "[" + traits.sorted().map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }
}

internal final class ManifestTraitConsistencyCollector: SyntaxVisitor {

    struct Dependency {
        let name: Swift::String
        let position: AbsolutePosition
        /// The traits of a `.when(traits:)` condition; nil when there is none.
        let traits: Swift::Set<Swift::String>?
        /// Where `, condition: …` goes: right after the last argument of a `.product(…)` with
        /// no condition. Nil when the dependency cannot be conditioned in place.
        let insertionOffset: Swift::Int?
    }

    struct Target {
        let name: Swift::String
        let path: Swift::String?
        let defaultRoot: Swift::String
        let dependencies: [Dependency]
    }

    /// Declared traits and the traits each enables.
    var traits: [Swift::String: [Swift::String]] = [:]

    var targets: [Target] = []

    var unhandledSourceShape: Swift::String?

    private static let roots: [Swift::String: Swift::String] = [
        "target": "Sources", "executableTarget": "Sources", "macro": "Sources", "testTarget": "Tests",
    ]

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else { return .visitChildren }
        let callee = member.declName.baseName.text
        if callee == "trait", !Self.isInside(Syntax(node), call: "package"),
            let name = Self.string(node, "name")
        {
            traits[name] = Self.strings(node.arguments.first { $0.label?.text == "enabledTraits" }?.expression) ?? []
        } else if let root = Self.roots[callee], let name = Self.string(node, "name") {
            var dependencies: [Dependency] = []
            for argument in node.arguments where argument.label?.text == "dependencies" {
                guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                    unhandledSourceShape = unhandledSourceShape ?? "computed target dependencies of '\(name)'"
                    continue
                }
                dependencies += array.elements.compactMap { dependency($0.expression) }
            }
            targets.append(Target(name: name, path: Self.string(node, "path"), defaultRoot: root, dependencies: dependencies))
            return .skipChildren
        }
        return .visitChildren
    }

    private func dependency(_ expression: ExprSyntax) -> Dependency? {
        let position = expression.positionAfterSkippingLeadingTrivia
        if let literal = expression.as(StringLiteralExprSyntax.self) {
            return manifestStringLiteralText(literal).map {
                Dependency(name: $0, position: position, traits: nil, insertionOffset: nil)
            }
        }
        guard let call = expression.as(FunctionCallExprSyntax.self),
            let callee = call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
            callee == "product" || callee == "byName",
            let name = Self.string(call, "name")
        else {
            if expression.as(FunctionCallExprSyntax.self) == nil {
                unhandledSourceShape = unhandledSourceShape ?? "unhandled target dependency '\(expression.trimmedDescription)'"
            }
            return nil
        }
        let condition = call.arguments.first { $0.label?.text == "condition" }?.expression.as(FunctionCallExprSyntax.self)
        let traits = Self.strings(condition?.arguments.first { $0.label?.text == "traits" }?.expression).map(Swift::Set.init)
        let insertable = callee == "product" && condition == nil
        return Dependency(
            name: name,
            position: position,
            traits: traits,
            insertionOffset: insertable ? call.arguments.last.map { $0.expression.endPositionBeforeTrailingTrivia.utf8Offset } : nil
        )
    }

    private static func isInside(_ node: Syntax, call name: Swift::String) -> Swift::Bool {
        var current = node.parent
        while let candidate = current {
            if let call = candidate.as(FunctionCallExprSyntax.self),
                call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == name
            {
                return true
            }
            current = candidate.parent
        }
        return false
    }

    private static func string(_ call: FunctionCallExprSyntax, _ label: Swift::String) -> Swift::String? {
        call.arguments.first { $0.label?.text == label }?.expression.as(StringLiteralExprSyntax.self)
            .flatMap(manifestStringLiteralText)
    }

    private static func strings(_ expression: ExprSyntax?) -> [Swift::String]? {
        expression?.as(ArrayExprSyntax.self)?.elements.compactMap {
            $0.expression.as(StringLiteralExprSyntax.self).flatMap(manifestStringLiteralText)
        }
    }
}
