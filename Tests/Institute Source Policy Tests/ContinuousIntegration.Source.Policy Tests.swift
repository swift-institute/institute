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
        #expect("\(policy.swiftFormat.path)" == ".swift-format")
        #expect(!policy.swiftFormatRepair.contents.isEmpty)
        #expect("\(policy.swiftFormatRepair.path)" == ".swift-format-repair")
        #expect(!policy.swiftLint.contents.isEmpty)
        #expect("\(policy.swiftLint.path)" == ".swiftlint.yml")
        #expect(policy.swiftLintRules.count == 116)
        #expect(policy.swiftLintRules.contains { $0.token == "typed_throws_required" })
        #expect(!policy.swiftLintRules.contains { $0.token == "custom_rules" })
        #expect(policy.bundles == [.primitives, .standards, .institute])
        for platform in Institute.Source.Policy.Platform.allCases {
            #expect(
                policy.engines.filter { $0.platform == platform }.map(\.id.token)
                    == ["swift-format", "swiftlint", "swift-linter"]
            )
        }
        #expect(policy.engines.count == 6)
    }

    @Test(arguments: Institute.Source.Policy.Platform.allCases)
    func `each platform pins one engine per required engine by a SHA-256 digest`(
        platform: Institute.Source.Policy.Platform
    ) throws {
        let policy = Institute.Source.Policy.current
        for id in policy.requiredEngines {
            let engine = try #require(policy.engine(id, on: platform))
            #expect(engine.platform == platform)
            #expect(engine.executable.digest.hex.utf8.count == 64)
            #expect(
                engine.executable.digest.hex.utf8.allSatisfy {
                    ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
                }
            )
        }
        #expect(policy.engine(.init("no-such-engine"), on: platform) == nil)
    }

    @Test
    func `Linux swift-format is the pinned Swift toolchain's own, found on the machine`() throws {
        let engine = try #require(
            Institute.Source.Policy.current.engine(.init("swift-format"), on: .linuxX86_64)
        )
        #expect(engine.version == "6.4.2")
        #expect(engine.revision == "swift-6.4.2-RELEASE")
        guard case .toolchain(let release, let distribution, let executable) = engine.executable.origin else {
            Issue.record("Linux swift-format is not the toolchain's")
            return
        }
        #expect(release == "swift-6.4.2-RELEASE")
        #expect(distribution == "ubuntu24.04")
        #expect(executable == "swift-format")
        #expect(
            engine.executable.digest
                == .init("50a1cb95ded4d8f4ac934649fe2b61b5ccabddace84848b9ffda0b4d9f915883")
        )
    }

    @Test
    func `Linux SwiftLint is the same release as macOS, from its Linux archive`() throws {
        let policy = Institute.Source.Policy.current
        let linux = try #require(policy.engine(.init("swiftlint"), on: .linuxX86_64))
        let macOS = try #require(policy.engine(.init("swiftlint"), on: .macOSARM64))
        #expect(linux.version == "0.65.1")
        #expect(linux.version == macOS.version)
        #expect(linux.schema == macOS.schema)
        guard case .releaseArchive(let base, let archive, let digest, let member) = linux.executable.origin,
            case .releaseArchive(let macOSBase, _, _, _) = macOS.executable.origin
        else {
            Issue.record("SwiftLint is not acquired from a release archive")
            return
        }
        #expect(base == macOSBase)
        #expect(base.hasSuffix("/0.65.1"))
        #expect(archive == "swiftlint_linux_amd64.zip")
        #expect(member == "swiftlint")
        #expect(digest == .init("caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d"))
        #expect(
            linux.executable.digest
                == .init("3384e7a44d6f2b6f9820404111e2a777b08ba99de087979ed40f6832efc073f5")
        )
    }

    @Test
    func `the linter runner is one revision's build on both platforms, named by its digest`() throws {
        let policy = Institute.Source.Policy.current
        let linux = try #require(policy.engine(.init("swift-linter"), on: .linuxX86_64))
        let macOS = try #require(policy.engine(.init("swift-linter"), on: .macOSARM64))
        #expect(linux.revision == macOS.revision)
        #expect(linux.schema == macOS.schema)
        for engine in [linux, macOS] {
            #expect(
                engine.executable.name
                    == "institute-linter-runner-\(engine.platform.token)-\(engine.executable.digest.hex)"
            )
        }
        #expect(
            linux.executable.digest
                == .init("3ac0a7a3fb2edeada752a89c9c55a4bea44cd103a3799b7552ef75f39ba2e505")
        )
    }

    @Test
    func `the linter's runtime environment joins its profile without replacing the bundle`() {
        let policy = Institute.Source.Policy.current
        func profile(_ environment: [Swift.String: Swift.String]) -> Source.Profile {
            policy.profile(
                swiftFormat: (executable: "/swift-format", tool: .init("format-tool"), configurationPath: "/.swift-format"),
                swiftLint: (executable: "/swiftlint", tool: .init("swiftlint-tool"), configurationPath: "/.swiftlint.yml"),
                linter: (executable: "/swift-linter", tool: .init("linter-tool"), configurationPath: "/source-linter-profile.json"),
                bundle: .institute,
                linterRules: [],
                linterEnvironment: environment
            )
        }
        func linter(_ profile: Source.Profile) -> [Swift.String: Swift.String]? {
            profile.engines.first { $0.id.token == "swift-linter" }?.environment
        }
        #expect(linter(profile([:])) == ["SWIFT_LINTER_BUNDLE": "institute"])
        #expect(
            linter(profile(["LD_LIBRARY_PATH": "/toolchain/usr/lib/swift/linux", "SWIFT_LINTER_BUNDLE": "other"]))
                == ["SWIFT_LINTER_BUNDLE": "institute", "LD_LIBRARY_PATH": "/toolchain/usr/lib/swift/linux"]
        )
        for other in ["swift-format", "swiftlint"] {
            #expect(
                profile(["LD_LIBRARY_PATH": "/x"]).engines.first { $0.id.token == other }?.environment == [:]
            )
        }
    }

    @Test
    func `swift format binds the hosted Xcode version and its digest`() throws {
        let engine = try #require(
            Institute.Source.Policy.current.engine(.init("swift-format"), on: .macOSARM64)
        )
        #expect(engine.revision == "27B52")
        #expect(engine.toolchain == "Xcode 27.2 (27B52)")
        guard case .xcode(_, let version, _) = engine.executable.origin else {
            Issue.record("swift-format is not acquired from Xcode")
            return
        }
        #expect(version == "27.2")
        #expect(
            engine.executable.digest
                == .init("475d31f48c068e4ebc05870bc0f1ae7e9bb8cae1520e1053212aa91b8d7b7d34")
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
            (.institute, 143, "6186e7d65ff96f9ca2f62e0d07d1a30badd710efe18bc9a61f7389711bf51b55"),
            (.primitives, 146, "a1d406014d14bcc78e9a9b815d70c3fe174e3b7e9e0976fa5cca61c9513b53d1"),
            (.standards, 139, "74d87c82b0e4d955389815434c14f59a43c0578699c7600895d0dceb89aca668"),
        ]
        let engine = policy.engine(.init("swift-linter"), on: .macOSARM64)
        #expect(engine?.revision == "b3e6db8375f437ca2ba9be32c23cb3a6c9c8e7b0")
        #expect(engine?.executable.digest == .init("0ff987f2cbccb115c65bbb6c0c2bfddfa4d10982b197df6c8f3217642f312607"))
        for (bundle, count, digest) in expected {
            let rules = policy.linterRules(for: bundle)
            #expect(rules.count == count)
            #expect(Set(rules).count == count)
            #expect(rules.map(\.token) == rules.map(\.token).sorted())
            #expect(policy.linter(bundle: bundle, rules: rules).digest == .init(digest))
        }
    }
}
