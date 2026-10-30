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
        #expect(policy.swiftLintRules.count == 116)
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
        #expect(engine.revision == "27B48")
        #expect(engine.toolchain == "Xcode 27.2 (27B48)")
        guard case .xcode(_, let version, _) = engine.executable.origin else {
            Issue.record("swift-format is not acquired from Xcode")
            return
        }
        #expect(version == "27.2")
        #expect(
            engine.executable.digest
                == .init("d16e078818b2dc41a6a977a8e6aaf57fb535c3e34f97bf087bb6e909b13a5d8f")
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
            swiftFormat: (executable: "/swift-format", tool: .init("format-tool"), configurationPath: "/.swift-format"),
            swiftLint: (executable: "/swiftlint", tool: .init("swiftlint-tool"), configurationPath: "/.swiftlint.yml"),
            linter: (executable: "/swift-linter", tool: .init("linter-tool"), configurationPath: "/source-linter-profile.json"),
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
                    swiftFormat: (executable: "/swift-format", tool: .init("format-tool"), configurationPath: "/.swift-format"),
                    swiftLint: (executable: "/swiftlint", tool: .init("swiftlint-tool"), configurationPath: "/.swiftlint.yml"),
                    linter: (executable: "/swift-linter", tool: .init("linter-tool"), configurationPath: "/source-linter-profile.json"),
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
                swiftFormat: (executable: "/swift-format", tool: .init("format-tool"), configurationPath: "/.swift-format"),
                swiftLint: (executable: "/swiftlint", tool: .init("swiftlint-tool"), configurationPath: "/.swiftlint.yml"),
                linter: (executable: "/swift-linter", tool: .init("linter-tool"), configurationPath: "/source-linter-profile.json"),
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
            (.institute, 136, "6c768bf37e8f3b329e3341d5af64edbc3cebd280eaf1f54a91b0471599d4ca43"),
            (.primitives, 139, "d16afe187e4bfbf40db6e67b275e1f01133b3a15c1681c617e1ec63976ad927f"),
            (.standards, 132, "df4b8c8dabfbb7999ca8e3e5bbef48f171daebec00839c5d4415f1ae98131f3c"),
        ]
        let engine = policy.engines.first { $0.id.token == "swift-linter" }
        #expect(engine?.revision == "c21431f03759cc83a3fc16d9dc8400bf34fa03f7")
        #expect(engine?.executable.digest == .init("ea30dccb456d562b5a16c90dbbcbbe577481e028ef550bf325d4ac9bc4cd700a"))
        for (bundle, count, digest) in expected {
            let rules = policy.linterRules(for: bundle)
            #expect(rules.count == count)
            #expect(Set(rules).count == count)
            #expect(rules.map(\.token) == rules.map(\.token).sorted())
            #expect(policy.linter(bundle: bundle, rules: rules).digest == .init(digest))
        }
    }
}
