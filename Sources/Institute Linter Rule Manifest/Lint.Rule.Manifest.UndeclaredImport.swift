public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `undeclared module import` = Lint.Rule(
        id: "undeclared module import",
        default: .warning,
        controls: [
            .init(
                id: "undeclared module import transitive standard",
                source: manifestUndeclaredImportFixture,
                path: "Package.swift",
                expectation: .findings(1),
                files: ["Sources/Kernel File/Kernel.File.Move.swift": "#if os(macOS)\ninternal import Darwin_Kernel_Standard\n#endif"]
            ),
            .init(
                id: "undeclared module import declared product and own target",
                source: manifestUndeclaredImportFixture,
                path: "Package.swift",
                expectation: .clean,
                files: [
                    "Sources/Kernel File/Kernel.File.Move.swift": "public import Darwin_Kernel\nimport Kernel_Core",
                    "Tests/Kernel File Tests/Move Tests.swift": "import Kernel_File\nimport Testing",
                ]
            ),
            .init(
                id: "undeclared module import system and single word modules",
                source: manifestUndeclaredImportFixture,
                path: "Package.swift",
                expectation: .clean,
                files: ["Sources/Kernel File/Kernel.File.Move.swift": "import Darwin\nimport _Concurrency\nimport Synchronization"]
            ),
            .init(
                id: "undeclared module import nested package",
                source: manifestUndeclaredImportFixture,
                path: "Package.swift",
                expectation: .clean,
                files: [
                    "Tests/Package.swift": "import PackageDescription",
                    "Tests/Sources/Probe/Probe.swift": "import Other_Module",
                ]
            ),
            .init(
                id: "undeclared module import test target",
                source: manifestUndeclaredImportFixture,
                path: "Package.swift",
                expectation: .findings(1),
                files: ["Tests/Kernel File Tests/Move Tests.swift": "import POSIX_Kernel_File"]
            ),
            .init(
                id: "undeclared module import outside manifest",
                source: "internal import Darwin_Kernel_Standard",
                path: "Sources/Kernel File/Kernel.File.Move.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let collector = ManifestDeclaredModuleCollector(viewMode: .sourceAccurate)
            collector.walk(source.tree)
            let nested = source.index.imports.keys.compactMap { path -> Swift::String? in
                let components = path.split(separator: "/")
                guard components.count > 1, components.last.map({ manifestIsManifestFilename(Swift::String($0)) }) == true
                else { return nil }
                return components.dropLast().joined(separator: "/") + "/"
            }
            var reported: Swift::Set<Swift::String> = []
            var findings: [Diagnostic.Record] = []
            let anchor = source.converter.location(for: collector.anchor ?? source.tree.positionAfterSkippingLeadingTrivia)
            for root in ["Sources", "Tests"] {
                for (path, entry) in source.index.imports(under: root) {
                    guard !nested.contains(where: { path.hasPrefix($0) }) else { continue }
                    let module = entry.module.split(separator: ".").first.map(Swift::String.init) ?? entry.module
                    guard !module.hasPrefix("_"), module.contains("_"),
                        !collector.modules.contains(module),
                        reported.insert(module).inserted
                    else { continue }
                    findings.append(
                        Diagnostic.Record(
                            location: Source.Location(
                                fileID: source.file.fileID,
                                filePath: source.file.filePath,
                                line: anchor.line,
                                column: anchor.column
                            ),
                            severity: severity,
                            identifier: "undeclared module import",
                            message: "[undeclared module import] [PACKAGE-DEPENDENCY-DECLARED]: `\(path):\(entry.line)` "
                                + "imports `\(module)`, which is neither a target of this package nor a "
                                + "product its manifest names. It builds only because another dependency "
                                + "pulls the module in. Name the product that provides it, or reach it "
                                + "through the package that re-exports it. The rule reads the manifest's "
                                + "spelling: it checks multi-word modules (`A_B`) against product and target "
                                + "names, and does not check single-word modules."
                        )
                    )
                }
            }
            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}

private let manifestUndeclaredImportFixture: Swift::String = """
    let package = Package(
        name: "swift-kernel",
        products: [.library(name: "Kernel File", targets: ["Kernel File"])],
        targets: [
            .target(name: "Kernel Core"),
            .target(
                name: "Kernel File",
                dependencies: [
                    "Kernel Core",
                    .product(name: "Darwin Kernel", package: "swift-darwin"),
                ]
            ),
            .testTarget(name: "Kernel File Tests", dependencies: ["Kernel File"]),
        ]
    )
    """

private func manifestIsManifestFilename(_ name: Swift::String) -> Swift::Bool {
    name == "Package.swift" || (name.hasPrefix("Package@swift-") && name.hasSuffix(".swift"))
}

internal final class ManifestDeclaredModuleCollector: SyntaxVisitor {
    var modules: Swift::Set<Swift::String> = []
    var anchor: AbsolutePosition?

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if anchor == nil, node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package" {
            anchor = node.positionAfterSkippingLeadingTrivia
        }
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            let argument = node.arguments.first(where: { $0.label?.text == "name" }),
            let literal = argument.expression.as(StringLiteralExprSyntax.self),
            let name = manifestStringLiteralText(literal),
            member.declName.baseName.text != "package"
        {
            modules.insert(Self.module(name))
        }
        return .visitChildren
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        if node.parent?.as(ArrayElementSyntax.self) != nil, let name = manifestStringLiteralText(node) {
            modules.insert(Self.module(name))
        }
        return .skipChildren
    }

    private static func module(_ name: Swift::String) -> Swift::String {
        Swift::String(name.map { $0 == " " || $0 == "-" ? "_" : $0 })
    }
}
