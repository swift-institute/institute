public import Institute_Model
import Institute_Source_Policy
import Source_Profile
import Testing

@Suite
struct `Institute source policy` {
    @Test
    func `migration policy requires all three engines`() {
        let policy = Institute.Source.Policy.current
        #expect(
            policy.requiredEngines.map(\.token)
                == ["swift-format", "swiftlint", "swift-linter"]
        )
        #expect(!policy.swiftFormat.contents.isEmpty)
        #expect(policy.swiftFormat.path == ".swift-format")
        #expect(!policy.swiftLint.contents.isEmpty)
        #expect(policy.swiftLint.path == ".swiftlint.yml")
        #expect(policy.bundles == [.primitives, .standards, .institute])
    }

    @Test
    func `profile binds tool configuration and exact rules`() {
        let policy = Institute.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [Source.Rule.ID(engine: linter, token: "rule")]
        let swiftLint = Source.Engine.ID("swiftlint")
        let swiftLintRules = [Source.Rule.ID(engine: swiftLint, token: "legacy_rule")]
        let profile = policy.profile(
            swiftFormatExecutable: "/swift-format",
            swiftFormatTool: .init("format-tool"),
            swiftFormatConfigurationPath: "/.swift-format",
            swiftLintExecutable: "/swiftlint",
            swiftLintTool: .init("swiftlint-tool"),
            swiftLintConfigurationPath: "/.swiftlint.yml",
            swiftLintRules: swiftLintRules,
            linterExecutable: "/swift-linter",
            linterTool: .init("linter-tool"),
            linterConfigurationPath: "/source-linter-profile.json",
            bundle: .institute,
            linterRules: rules
        )
        // The profile canonicalizes engine order by identifier; the
        // policy's own required-engine order is asserted separately above.
        #expect(
            profile.engines.map(\.id.token).sorted()
                == ["swift-format", "swift-linter", "swiftlint"]
        )
        func engine(_ token: String) -> Source.Profile.Engine? {
            profile.engines.first { $0.id.token == token }
        }
        #expect(engine("swift-format")?.rules.map(\.token) == ["format"])
        #expect(engine("swiftlint")?.rules == swiftLintRules)
        #expect(engine("swift-linter")?.rules == rules)
        #expect(
            profile.digest
                == policy.profile(
                    swiftFormatExecutable: "/swift-format",
                    swiftFormatTool: .init("format-tool"),
                    swiftFormatConfigurationPath: "/.swift-format",
                    swiftLintExecutable: "/swiftlint",
                    swiftLintTool: .init("swiftlint-tool"),
                    swiftLintConfigurationPath: "/.swiftlint.yml",
                    swiftLintRules: swiftLintRules,
                    linterExecutable: "/swift-linter",
                    linterTool: .init("linter-tool"),
                    linterConfigurationPath: "/source-linter-profile.json",
                    bundle: .institute,
                    linterRules: rules
                ).digest
        )
    }
}
