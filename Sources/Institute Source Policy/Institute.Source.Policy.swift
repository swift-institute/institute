public import Institute_Model
public import Source_Profile

extension Institute.Source {
    public struct Policy: Sendable {
        public static let current = Self(revision: "source-enforcement-v3")

        public let revision: Swift.String
        public let requiredEngines: [Source_Profile.Source.Engine.ID]
        public let swiftFormat: Artifact
        public let swiftLint: Artifact
        public let engines: [Engine]
        public let bundles: [Bundle]
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
            self.swiftLint = .init(
                path: ".swiftlint.yml",
                contents: Self.swiftLintConfiguration,
                schema: "swiftlint:0.65.0"
            )
            self.engines = [
                .init(
                    id: .init("swift-format"),
                    platform: .macOSARM64,
                    version: "main",
                    revision: "27A5237l",
                    toolchain: "Xcode 27.0 (27A5237l)",
                    schema: "swift-format:main",
                    executable: .init(
                        name: "swift-format",
                        digest: .init(
                            "649ef37b500751f36258ce7fce0a47f1348a542f1ec6b54d52428064fae5c9a9"
                        ),
                        origin: .xcode(
                            application: "/Applications/Xcode-beta.app",
                            version: "27.0",
                            build: "27A5237l",
                            relativePath:
                                "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
                        )
                    ),
                    manifest: nil,
                    inventory: nil,
                    checksums: nil
                ),
                .init(
                    id: .init("swiftlint"),
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
                    revision: "aa5ae962c9892e1b875fbc922058c9af62907b74",
                    toolchain: "Xcode 27.0 (27A5228h)",
                    schema: "swift-linter-structured:2",
                    executable: .init(
                        name: "swift-linter-macos-arm64",
                        digest: .init(
                            "a6e805c038ce422749b0491beb391e07fcd1d1a89bdbc326605bd8a95d451a06"
                        ),
                        origin: .release(
                            base:
                                "https://github.com/swift-foundations/swift-linter/releases/download/ci-binaries"
                        )
                    ),
                    manifest: nil,
                    inventory: nil,
                    checksums: nil
                ),
            ]
            self.bundles = Bundle.allCases
            self.commitment = .init(
                repositories: [
                    "swift-foundations/swift-linter",
                    "swift-foundations/swift-linter-rules",
                    "swift-foundations/swift-institute-linter-rules",
                    "swift-foundations/swift-source",
                    "swift-primitives/swift-linter-primitives",
                    "swift-primitives/swift-primitives-linter-rules",
                    "swift-primitives/swift-source-primitives",
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
            let document = JSON.object([
                ("schema", 1),
                ("revision", JSON(stringLiteral: revision)),
                ("bundle", JSON(stringLiteral: bundle.token)),
                ("rules", rules.sorted(by: { $0.token < $1.token }).json),
            ])
            return .init(
                path: "source-linter-profile.json",
                contents: document.serialize(pretty: false) + "\n",
                schema: "swift-linter-profile:1"
            )
        }

        public func profile(
            swiftFormatExecutable: Swift.String,
            swiftFormatTool: Source_Profile.Source.Profile.Digest,
            swiftFormatConfigurationPath: Swift.String,
            swiftLintExecutable: Swift.String,
            swiftLintTool: Source_Profile.Source.Profile.Digest,
            swiftLintConfigurationPath: Swift.String,
            swiftLintRules: [Source_Profile.Source.Rule.ID],
            linterExecutable: Swift.String,
            linterTool: Source_Profile.Source.Profile.Digest,
            linterConfigurationPath: Swift.String,
            bundle: Bundle,
            linterRules: [Source_Profile.Source.Rule.ID]
        ) -> Source_Profile.Source.Profile {
            let swiftFormatID = Source_Profile.Source.Engine.ID("swift-format")
            let swiftLintID = Source_Profile.Source.Engine.ID("swiftlint")
            let linterID = Source_Profile.Source.Engine.ID("swift-linter")
            return Source_Profile.Source.Profile(
                revision: revision,
                engines: [
                    .init(
                        id: swiftFormatID,
                        executable: swiftFormatExecutable,
                        tool: swiftFormatTool,
                        configuration: swiftFormat.digest,
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
