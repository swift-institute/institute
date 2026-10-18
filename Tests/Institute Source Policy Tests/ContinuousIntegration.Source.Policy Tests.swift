public import Institute_Model
import Institute_Source_Policy
import JSON
import Source_Profile
import Testing

@Suite
struct `Institute source policy` {
    @Test
    func `transitional policy requires all three source engines`() {
        let policy = Institute.Source.Policy.current
        #expect(
            policy.requiredEngines.map(\.token)
                == ["swift-format", "swiftlint", "swift-linter"]
        )
        #expect(!policy.swiftFormat.contents.isEmpty)
        #expect(policy.swiftFormat.path == ".swift-format")
        #expect(!policy.swiftFormatRepair.contents.isEmpty)
        #expect(policy.swiftFormatRepair.path == ".swift-format-repair")
        #expect(!policy.swiftLint.contents.isEmpty)
        #expect(policy.swiftLint.path == ".swiftlint.yml")
        #expect(policy.swiftLintRules.count == 117)
        #expect(policy.swiftLintRules.contains { $0.token == "typed_throws_required" })
        #expect(!policy.swiftLintRules.contains { $0.token == "custom_rules" })
        #expect(policy.bundles == [.primitives, .standards, .institute])
        #expect(
            policy.engines.map(\.id.token)
                == ["swift-format", "swiftlint", "swift-linter"]
        )
    }

    @Test
    func `swift format binds the hosted Xcode version and its digest`() throws {
        let engine = try #require(
            Institute.Source.Policy.current.engines.first { $0.id.token == "swift-format" }
        )
        #expect(engine.revision == "27A9269")
        #expect(engine.toolchain == "Xcode 27.1 (27A9269)")
        guard case .xcode(_, let version, _) = engine.executable.origin else {
            Issue.record("swift-format is not acquired from Xcode")
            return
        }
        #expect(version == "27.1")
        #expect(
            engine.executable.digest
                == .init("1b4fc083a7b8e21b23b2478dadb996f736a901fa9ff0a14145d981d45989b6ec")
        )
    }

    @Test
    func `documentation rules left the swift-format configuration`() {
        let policy = Institute.Source.Policy.current
        for retired in [
            "AllPublicDeclarationsHaveDocumentation",
            "BeginDocumentationCommentWithOneLineSummary",
            "ValidateDocumentationComments",
        ] {
            #expect(!policy.swiftFormat.contents.contains(retired))
            #expect(!policy.swiftFormatRepair.contents.contains(retired))
        }
    }

    @Test
    func `repair configuration enables only format-correctable rules`() throws {
        let policy = Institute.Source.Policy.current
        let measure = try rules(in: policy.swiftFormat.contents)
        let repair = try rules(in: policy.swiftFormatRepair.contents)
        #expect(Set(measure.keys) == Set(repair.keys))
        for (rule, enabled) in repair where enabled {
            #expect(measure[rule] == true)
        }
        for lintOnly in ["NeverForceUnwrap", "NeverUseForceTry", "NoBlockComments"] {
            #expect(measure[lintOnly] == true)
            #expect(repair[lintOnly] == false)
        }
        for correctable in ["DoNotUseSemicolons", "OrderedImports"] {
            #expect(repair[correctable] == true)
        }
        for judgmentOrDocumentation in [
            "UseEarlyExits", "UseTripleSlashForDocumentationComments",
        ] {
            #expect(measure[judgmentOrDocumentation] == true)
            #expect(repair[judgmentOrDocumentation] == false)
        }
    }

    @Test
    func `rendered linter profile carries schema two rules without unrelated applicability`() throws {
        let policy = Institute.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [
            Source.Rule.ID(engine: linter, token: "b rule"),
            Source.Rule.ID(engine: linter, token: "a rule"),
        ]
        let artifact = policy.linter(bundle: .institute, rules: rules)
        let document = try JSON.parse(artifact.contents)
        let object = try #require(document.dictionary)
        #expect(try Swift.Int(json: #require(object["schema"])) == 2)
        #expect(try Swift.String(json: #require(object["bundle"])) == "institute")
        let rendered = try [Swift.String](json: #require(object["rules"]))
        #expect(rendered == ["a rule", "b rule"])
        #expect(try [JSON](json: #require(object["applicability"])).isEmpty)
    }

    @Test
    func `compound identifier profile carries exact externally standardized target identity`() throws {
        let policy = Institute.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [Source.Rule.ID(engine: linter, token: "compound identifier")]
        let artifact = policy.linter(bundle: .institute, rules: rules)
        let document = try JSON.parse(artifact.contents)
        let object = try #require(document.dictionary)
        let applications = try [JSON](json: #require(object["applicability"]))
        let application = try #require(applications.first?.dictionary)
        #expect(try Swift.String(json: #require(application["rule"])) == "compound identifier")
        let targets = try [JSON](json: #require(application["excludedTargets"]))
        let target = try #require(targets.first?.dictionary)
        #expect(try Swift.String(json: #require(target["identity"])) == "CSS")
        #expect(try Swift.String(json: #require(target["sourceRoot"])) == "Sources/CSS/")
    }

    @Test
    func `profile binds tool configuration and exact rules`() {
        let policy = Institute.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [Source.Rule.ID(engine: linter, token: "rule")]
        let profile = policy.profile(
            swiftFormatExecutable: "/swift-format",
            swiftFormatTool: .init("format-tool"),
            swiftFormatConfigurationPath: "/.swift-format",
            swiftLintExecutable: "/swiftlint",
            swiftLintTool: .init("swiftlint-tool"),
            swiftLintConfigurationPath: "/.swiftlint.yml",
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
        #expect(engine("swiftlint")?.rules == policy.swiftLintRules)
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
                    linterExecutable: "/swift-linter",
                    linterTool: .init("linter-tool"),
                    linterConfigurationPath: "/source-linter-profile.json",
                    bundle: .institute,
                    linterRules: rules
                ).digest
        )
    }

    @Test
    func `repair profile binds the repair-scoped configuration`() {
        let policy = Institute.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [Source.Rule.ID(engine: linter, token: "rule")]
        func profile(repair: Bool) -> Source.Profile {
            policy.profile(
                swiftFormatExecutable: "/swift-format",
                swiftFormatTool: .init("format-tool"),
                swiftFormatConfigurationPath: "/.swift-format",
                swiftLintExecutable: "/swiftlint",
                swiftLintTool: .init("swiftlint-tool"),
                swiftLintConfigurationPath: "/.swiftlint.yml",
                linterExecutable: "/swift-linter",
                linterTool: .init("linter-tool"),
                linterConfigurationPath: "/source-linter-profile.json",
                bundle: .institute,
                linterRules: rules,
                repair: repair
            )
        }
        func format(_ profile: Source.Profile) -> Source.Profile.Engine? {
            profile.engines.first { $0.id.token == "swift-format" }
        }
        #expect(
            format(profile(repair: false))?.configuration == policy.swiftFormat.digest
        )
        #expect(
            format(profile(repair: true))?.configuration == policy.swiftFormatRepair.digest
        )
        #expect(profile(repair: false).digest != profile(repair: true).digest)
    }

    private func rules(
        in configuration: Swift.String
    ) throws -> [Swift.String: Swift.Bool] {
        let document = try JSON.parse(configuration)
        let object = try #require(document.dictionary)
        let rules = try #require(object["rules"]).dictionary
        var decoded: [Swift.String: Swift.Bool] = [:]
        for (name, value) in try #require(rules) {
            decoded[name] = try Swift.Bool(json: value)
        }
        return decoded
    }
}


extension `Institute source policy` {
    @Test
    func `adopted linter catalog preserves published bundle identities and profiles`() {
        let policy = Institute.Source.Policy.current
        let expected: [(Institute.Source.Bundle, Swift.Int, Swift.String)] = [
            (.institute, 126, "38ead8dc815a42fe7e9a11a82ddfdfe01b2589acee9e1129cf7887f4955df82e"),
            (.primitives, 129, "4690d0ce661ed7ac8a287cdd1c0209ba3a9219a6d95cd6b21ca71ed763890c60"),
            (.standards, 122, "1792673e3453fa926688807127816aa8561e16702c5a1805332405cf93787681"),
        ]
        let engine = policy.engines.first { $0.id.token == "swift-linter" }
        #expect(engine?.revision == "51fdb39b59d5d4b98094e5de93827e5fcf1579b4")
        #expect(engine?.executable.digest == .init("8fa9e133334cab6033e5183238d2a422183b2dd844bc07f2dcaebb3e98da76ce"))
        for (bundle, count, digest) in expected {
            let rules = policy.linterRules(for: bundle)
            #expect(rules.count == count)
            #expect(Set(rules).count == count)
            #expect(rules.map(\.token) == rules.map(\.token).sorted())
            #expect(policy.linter(bundle: bundle, rules: rules).digest == .init(digest))
        }
    }
}
