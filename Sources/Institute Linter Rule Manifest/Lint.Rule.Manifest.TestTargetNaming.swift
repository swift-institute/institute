public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `test target naming` = Lint.Rule(
        id: "test target naming",
        default: .warning,
        controls: [
            .init(
                id: "test target naming matching",
                source: "let package = Package(name: \"Fixture\", targets: ["
                    + ".target(name: \"Fixture Core\"), .testTarget(name: \"Fixture Core Tests\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "test target naming missing suffix",
                source: "let package = Package(name: \"Fixture\", targets: ["
                    + ".target(name: \"Fixture Core\"), .testTarget(name: \"FixtureCoreTests\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "test target naming no subject",
                source: "let package = Package(name: \"Fixture\", targets: ["
                    + ".target(name: \"Fixture Core\"), .testTarget(name: \"Fixture Tests\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "test target naming outside manifest",
                source: "let target = Target.testTarget(name: \"FixtureTests\")",
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
            let visitor = ManifestTestTargetNamingVisitor(viewMode: .sourceAccurate)
            visitor.walk(source.tree)
            let subjects = Swift::Set(visitor.targets.map(\.name))
            var seen: Swift::Set<Swift::String> = []
            var findings: [Diagnostic.Record] = []
            for test in visitor.testTargets {
                let reason: Swift::String? =
                    if !test.name.hasSuffix(" Tests") {
                        "`\(test.name)` must be named `<Target> Tests`."
                    } else if !subjects.contains(Swift::String(test.name.dropLast(" Tests".count))) {
                        "`\(test.name)` names no target of this package; a test target tests exactly one target."
                    } else if !seen.insert(test.name).inserted {
                        "`\(test.name)` is declared twice; one test target per target."
                    } else {
                        nil
                    }
                guard let reason else { continue }
                let location = source.converter.location(for: test.position)
                findings.append(
                    Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.file.fileID,
                            filePath: source.file.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: "test target naming",
                        message: "[test target naming] [PACKAGE-TEST-TARGET-NAMING]: \(reason)"
                    )
                )
            }
            let coverage: Lint.Rule.Coverage =
                visitor.unnamed
                ? .unmeasured(.unsupportedSourceShape("target name is not a string literal"))
                : .measured
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

private let manifestSubjectTargetFactories: Swift::Set<Swift::String> = [
    "target", "executableTarget", "macro", "plugin", "systemLibrary", "binaryTarget",
]

internal final class ManifestTestTargetNamingVisitor: SyntaxVisitor {
    struct Declared {
        let name: Swift::String
        let position: AbsolutePosition
    }

    var targets: [Declared] = []
    var testTargets: [Declared] = []
    var unnamed = false

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        let factory = member.declName.baseName.text
        let isTest = factory == "testTarget"
        guard isTest || manifestSubjectTargetFactories.contains(factory),
            let argument = node.arguments.first(where: { $0.label?.text == "name" })
        else {
            return .visitChildren
        }
        guard let literal = argument.expression.as(StringLiteralExprSyntax.self),
            let name = manifestStringLiteralText(literal)
        else {
            unnamed = unnamed || isTest
            return .visitChildren
        }
        let declared = Declared(name: name, position: node.positionAfterSkippingLeadingTrivia)
        if isTest {
            testTargets.append(declared)
        } else {
            targets.append(declared)
        }
        return .visitChildren
    }
}
