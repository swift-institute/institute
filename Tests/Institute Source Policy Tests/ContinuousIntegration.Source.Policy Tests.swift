import Institute_Source_Policy
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
        #expect(
            profile.engines.map(\.id.token)
                == ["swift-format", "swiftlint", "swift-linter"]
        )
        #expect(profile.engines[0].rules.map(\.token) == ["format"])
        #expect(profile.engines[1].rules == swiftLintRules)
        #expect(profile.engines[2].rules == rules)
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
