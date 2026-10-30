public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `package policy revision 1` = Lint.Rule(
        id: "package policy revision 1",
        default: .error,
        controls: [
            .init(
                id: "package policy revision 1 tools 63",
                source: "// swift-tools-version: 6.3\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [], swiftLanguageModes: [.v6])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "package policy revision 1 tools 64",
                source: "// swift-tools-version: 6.4\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [], swiftLanguageModes: [.v6])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "package policy revision 1 no target settings",
                source: "// swift-tools-version: 6.4\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [.target(name: \"Fixture\")], swiftLanguageModes: [.v6])",
                path: "Package.swift",
                expectation: .findings(7)
            ),
            .init(
                id: "package policy revision 1 settings loop without macro exclusion",
                source: "// swift-tools-version: 6.4\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [.target(name: \"Fixture\")], swiftLanguageModes: [.v6])\n"
                    + "for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {\n"
                    + "    target.swiftSettings = (target.swiftSettings ?? []) + [.strictMemorySafety(), "
                    + ".enableUpcomingFeature(\"ExistentialAny\"), .enableUpcomingFeature(\"InternalImportsByDefault\"), "
                    + ".enableUpcomingFeature(\"MemberImportVisibility\"), .enableUpcomingFeature(\"NonisolatedNonsendingByDefault\"), "
                    + ".enableExperimentalFeature(\"Lifetimes\"), .enableUpcomingFeature(\"InferIsolatedConformances\")]\n}",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "package policy revision 1 nested non-manifest",
                source: "// swift-tools-version: 6.3\n",
                path: "Tests/Fixtures/plain/Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
            .init(
                id: "package policy revision 1 nested manifest",
                source: "// swift-tools-version: 6.3\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [], swiftLanguageModes: [.v6])",
                path: "Tests/Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "package policy revision 1 versioned manifest",
                source: "// swift-tools-version: 6.4\nimport PackageDescription\n"
                    + "let package = Package(name: \"Fixture\", targets: [], swiftLanguageModes: [.v6])",
                path: "Package@swift-6.4.swift",
                expectation: .clean
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

            let inspection = ManifestPackagePolicyInspection(
                source.tree,
                filePath: source.file.filePath
            )
            if let reason = inspection.unmeasuredReason {
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: .unmeasured(.unsupportedSourceShape(reason))
                )
            }

            let location = Source.Location(
                fileID: source.file.fileID,
                filePath: source.file.filePath,
                line: 1,
                column: 1
            )
            var findings: [Diagnostic.Record] = []

            func require(_ condition: Swift::Bool, _ message: Swift::String) {
                guard !condition else { return }
                findings.append(
                    Diagnostic.Record(
                        location: location,
                        severity: severity,
                        identifier: "package policy revision 1",
                        message: "[package policy revision 1]: \(message)"
                    )
                )
            }

            require(
                inspection.toolsVersionIs64,
                "the manifest must declare `swift-tools-version: 6.4`."
            )
            require(
                inspection.languageModeIsV6,
                "the package must declare `swiftLanguageModes: [.v6]`."
            )
            for platform in inspection.applePlatformsNotAtV27.sorted() {
                require(
                    false,
                    "the declared Apple platform `\(platform)` must use minimum `.v27`."
                )
            }
            if inspection.hasOrdinaryTargets {
                for setting in inspection.missingOrdinaryTargetSettings.sorted() {
                    require(
                        false,
                        "every ordinary Swift target must receive `\(setting)`."
                    )
                }
            }
            require(
                !inspection.hasL1MacroTarget,
                "an L1 primitives package must not declare a macro target."
            )

            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}
