public import Institute_Model
public import Source_Profile

extension Institute.Source {
    public struct Policy: Sendable {
        public static let current = Self(revision: "source-enforcement-v3")

        public let revision: Swift.String
        public let requiredEngines: [Source_Profile.Source.Engine.ID]
        public let swiftFormat: Artifact
        public let swiftFormatRepair: Artifact
        public let swiftLint: Artifact
        public let swiftLintRules: [Source_Profile.Source.Rule.ID]
        public let engines: [Engine]
        public let bundles: [Bundle]
        public let externallyStandardizedTargets: [ExternallyStandardizedTarget]
        public let negativeControls: [NegativeControl]
        public let commitment: Commitment
        public let configuration: Configuration

        public init(revision: Swift.String) {
            self.revision = revision
            self.requiredEngines = [
                .init("swift-format"),
                .init("swiftlint"),
                .init("swift-linter"),
            ]
            self.swiftFormat = .init(
                path: ".swift-format",
                contents: Self.swiftFormatConfiguration,
                schema: "swift-format:1"
            )
            self.swiftFormatRepair = .init(
                path: ".swift-format-repair",
                contents: Self.swiftFormatRepairConfiguration,
                schema: "swift-format:1"
            )
            self.swiftLint = .init(
                path: ".swiftlint.yml",
                contents: Self.swiftLintConfiguration,
                schema: "swiftlint:0.65.0"
            )
            let swiftLintID = Source_Profile.Source.Engine.ID("swiftlint")
            self.swiftLintRules = Self.swiftLintRuleTokens.map {
                .init(engine: swiftLintID, token: $0)
            }
            self.engines = [
                .init(
                    id: .init("swift-format"),
                    platform: .macOSARM64,
                    version: "main",
                    revision: "27A9269",
                    toolchain: "Xcode 27.1 (27A9269)",
                    schema: "swift-format:main",
                    executable: .init(
                        name: "swift-format",
                        digest: .init(
                            "1b4fc083a7b8e21b23b2478dadb996f736a901fa9ff0a14145d981d45989b6ec"
                        ),
                        origin: .xcode(
                            application: "/Applications/Xcode_27.1.app",
                            version: "27.1",
                            relativePath:
                                "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
                        )
                    ),
                    manifest: nil,
                    inventory: nil,
                    checksums: nil
                ),
                .init(
                    id: swiftLintID,
                    platform: .macOSARM64,
                    version: "0.65.0",
                    revision: "0.65.0",
                    toolchain: "portable SwiftLint release",
                    schema: "swiftlint-json:0.65.0",
                    executable: .init(
                        name: "swiftlint",
                        digest: .init(
                            "06bdd57b59087dde8680ba6a62452defd71babd0513023f19ddfc6773708ba34"
                        ),
                        origin: .releaseArchive(
                            base: "https://github.com/realm/SwiftLint/releases/download/0.65.0",
                            archive: "portable_swiftlint.zip",
                            digest: .init(
                                "d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6"
                            ),
                            member: "swiftlint"
                        )
                    ),
                    manifest: nil,
                    inventory: nil,
                    checksums: nil
                ),
                .init(
                    id: .init("swift-linter"),
                    platform: .macOSARM64,
                    version: "ci-binaries",
                    revision: "53e591fd18d0066b7c5cf633a4ed6b0b86e52886",
                    toolchain: "Xcode 27.1;Build version 27A9275;",
                    schema: "swift-linter-structured:2",
                    executable: .init(
                        name: "swift-linter-macos-arm64-53e591fd18d0066b7c5cf633a4ed6b0b86e52886",
                        digest: .init(
                            "8d06030fc1b5c2ed0a1dc7e4859fdb1fa9502fad137e13e3ebca8000a7ad7021"
                        ),
                        origin: .release(
                            base:
                                "https://github.com/swift-compositions/swift-linter/releases/download/ci-binaries"
                        )
                    ),
                    manifest: nil,
                    inventory: nil,
                    checksums: nil
                ),
            ]
            self.bundles = Bundle.allCases
            self.externallyStandardizedTargets = [.init("CSS")]
            let linterID = Source_Profile.Source.Engine.ID("swift-linter")
            let swiftFormatID = Source_Profile.Source.Engine.ID("swift-format")
            self.negativeControls = [
                .init(
                    repository: "swift-institute/institute",
                    path: "Tests/Institute CI Validation Tests/Fixtures/test-009/fail/swift-compound-names/Tests/Foo Primitives Tests/FooBufferTests.swift",
                    rule: .init(engine: linterID, token: "test file suffix")
                ),
                .init(
                    repository: "swift-institute/institute",
                    path: "Tests/Institute CI Validation Tests/Fixtures/test-009/fail/swift-dot-before-tests/Tests/Foo Primitives Tests/Foo.Buffer.Tests.swift",
                    rule: .init(engine: linterID, token: "test file suffix")
                ),
                .init(
                    repository: "swift-compositions/swift-linter",
                    path: "Tests/Fixtures/runner-controls/error/Sources/Naming Core/ImplBinding.swift",
                    rule: .init(engine: linterID, token: "variable named impl")
                ),
                .init(
                    repository: "swift-atoms/swift-segment",
                    path: "Tests/Temporal Typechecking/InvalidClockCoordinateInstant.swift",
                    rule: .init(engine: swiftFormatID, token: "format"),
                    findings: 1
                ),
                .init(
                    repository: "swift-atoms/swift-segment",
                    path: "Tests/Temporal Typechecking/InvalidGenericCoordinateInstant.swift",
                    rule: .init(engine: swiftFormatID, token: "format"),
                    findings: 1
                ),
                .init(
                    repository: "swift-atoms/swift-segment",
                    path: "Tests/Temporal Typechecking/InvalidMixedDomainAffine.swift",
                    rule: .init(engine: swiftFormatID, token: "format"),
                    findings: 2
                ),
                .init(
                    repository: "swift-atoms/swift-segment",
                    path: "Tests/Temporal Typechecking/InvalidTemporalCoordinateInstant.swift",
                    rule: .init(engine: swiftFormatID, token: "format"),
                    findings: 1
                ),
                .init(
                    repository: "swift-atoms/swift-segment",
                    path: "Tests/Temporal Typechecking/InvalidTimeInstantProtocol.swift",
                    rule: .init(engine: swiftFormatID, token: "format"),
                    findings: 1
                ),
            ]
            self.commitment = .init(
                repositories: [
                    "swift-compositions/swift-linter",
                    "swift-compositions/swift-linter-rules",
                    "swift-compositions/swift-institute-linter-rules",
                    "swift-molecules/swift-lint",
                    "swift-molecules/swift-primitives-linter-rules",
                    "swift-molecules/swift-source",
                    "swift-standards/swift-standards-linter-rules",
                ],
                controls: ["application", "institute", "continuous-integration"],
                rule: .init(suffix: "-linter-rules")
            )
            let engine = Source_Profile.Source.Engine.ID("source-policy")
            self.configuration = .init(
                engine: engine,
                predicate: .init(engine: engine, token: "exact-configuration")
            )
        }

        public func linter(
            bundle: Bundle,
            rules: [Source_Profile.Source.Rule.ID]
        ) -> Artifact {
            let compoundIdentifier = Source_Profile.Source.Rule.ID(
                engine: .init("swift-linter"),
                token: "compound identifier"
            )
            let applicability: JSON =
                if rules.contains(compoundIdentifier) {
                    .array([
                        .object([
                            ("rule", JSON(stringLiteral: compoundIdentifier.token)),
                            (
                                "excludedTargets",
                                .array(
                                    externallyStandardizedTargets.sorted {
                                        $0.identity < $1.identity
                                    }.map { target in
                                        .object([
                                            ("identity", JSON(stringLiteral: target.identity)),
                                            ("sourceRoot", JSON(stringLiteral: target.sourceRoot)),
                                        ])
                                    }
                                )
                            ),
                        ])
                    ])
                } else {
                    .array([])
                }
            let document = JSON.object([
                ("schema", 2),
                ("revision", JSON(stringLiteral: revision)),
                ("bundle", JSON(stringLiteral: bundle.token)),
                ("applicability", applicability),
                (
                    "rules",
                    .array(
                        rules.map(\.token).sorted().map(JSON.init(stringLiteral:))
                    )
                ),
            ])
            return .init(
                path: "source-linter-profile.json",
                contents: document.serialize(pretty: false) + "\n",
                schema: "swift-linter-profile:2"
            )
        }

        public func profile(
            swiftFormat formatInstallation: (executable: Swift.String, tool: Source_Profile.Source.Profile.Digest, configurationPath: Swift.String),
            swiftLint lintInstallation: (executable: Swift.String, tool: Source_Profile.Source.Profile.Digest, configurationPath: Swift.String),
            linter linterInstallation: (executable: Swift.String, tool: Source_Profile.Source.Profile.Digest, configurationPath: Swift.String),
            bundle: Bundle,
            linterRules: [Source_Profile.Source.Rule.ID],
            repair: Swift.Bool = false
        ) -> Source_Profile.Source.Profile {
            let (swiftFormatExecutable, swiftFormatTool, swiftFormatConfigurationPath) = formatInstallation
            let (swiftLintExecutable, swiftLintTool, swiftLintConfigurationPath) = lintInstallation
            let (linterExecutable, linterTool, linterConfigurationPath) = linterInstallation
            let swiftFormatID = Source_Profile.Source.Engine.ID("swift-format")
            let swiftLintID = Source_Profile.Source.Engine.ID("swiftlint")
            let linterID = Source_Profile.Source.Engine.ID("swift-linter")
            let formatConfiguration = repair ? swiftFormatRepair : swiftFormat
            return Source_Profile.Source.Profile(
                revision: revision,
                engines: [
                    .init(
                        id: swiftFormatID,
                        executable: swiftFormatExecutable,
                        tool: swiftFormatTool,
                        configuration: formatConfiguration.digest,
                        configurationPath: swiftFormatConfigurationPath,
                        artifactKinds: [.swift],
                        rules: [.init(engine: swiftFormatID, token: "format")]
                    ),
                    .init(
                        id: swiftLintID,
                        executable: swiftLintExecutable,
                        tool: swiftLintTool,
                        configuration: swiftLint.digest,
                        configurationPath: swiftLintConfigurationPath,
                        artifactKinds: [.swift],
                        rules: swiftLintRules
                    ),
                    .init(
                        id: linterID,
                        executable: linterExecutable,
                        tool: linterTool,
                        configuration: linter(bundle: bundle, rules: linterRules).digest,
                        configurationPath: linterConfigurationPath,
                        environment: ["SWIFT_LINTER_BUNDLE": bundle.token],
                        artifactKinds: [.swift],
                        rules: linterRules
                    ),
                ]
            )
        }
    }
}
