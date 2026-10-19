import Byte
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy Caller Tests` {
    /// The canonical terminal caller, byte for byte. The wave's census,
    /// digests, and `already-terminal` classification all key on these
    /// exact bytes, so the fixture is the full document rather than a
    /// property list: any drift — a reordered trigger, a changed indent,
    /// a lost trailing newline — is a visible fixture change here first.
    static let terminalBytesFixture = """
        name: CI

        on:
          push:
            branches:
              - main
          pull_request:
            branches:
              - main
          merge_group:
            types:
              - checks_requested
          workflow_dispatch:

        permissions:
          actions: read
          contents: read

        concurrency:
          group: ci-${{ github.ref }}
          cancel-in-progress: true

        jobs:
          ci:
            if: ${{ !github.event.repository.private }}
            name: ci / matrix
            uses: swift-institute/.github/.github/workflows/swift-ci.yml@main

        """

    @Test
    func `terminal bytes equal the canonical fixture exactly`() {
        #expect(Institute.Repository.Policy.Caller.Render.terminal == Self.terminalBytesFixture)
    }

    /// Negative control on the fixture comparison itself: equality that
    /// survives a one-byte drift is not a byte census. One byte is
    /// removed, one is substituted, and one is appended; each variant
    /// must compare unequal.
    @Test
    func `terminal bytes comparison detects one-byte drift`() {
        let canonical = Institute.Repository.Policy.Caller.Render.terminal
        var dropped = canonical
        dropped.removeLast()
        #expect(dropped != canonical)
        let substituted = CallerFoundation.replacingOccurrences(
            in: canonical,
            of: "merge_group:",
            with: "merge_groUp:"
        )
        #expect(substituted != canonical)
        #expect(canonical + "\n" != canonical)
        // The digest the wave records over these bytes moves with them.
        let digest = Institute.Repository.Policy.Caller.Wave.digest([Byte](utf8: canonical))
        #expect(Institute.Repository.Policy.Caller.Wave.digest([Byte](utf8: dropped)) != digest)
        #expect(Institute.Repository.Policy.Caller.Wave.digest([Byte](utf8: substituted)) != digest)
    }

    /// The merge_group trigger fires only `checks_requested`, and today no
    /// repository has a merge queue, so the event is never delivered: the
    /// trigger is inert. The declaration itself is asserted structurally
    /// so a widening (more types, filters) is a deliberate change.
    @Test
    func `terminal merge group trigger is the single checks-requested declaration`() {
        let expected = Institute.Repository.Policy.Caller.Render.terminal
        #expect(
            expected.contains(
                "  merge_group:\n    types:\n      - checks_requested\n  workflow_dispatch:"
            )
        )
        // Exactly one declaration, and no other merge_group surface.
        #expect(CallerFoundation.components(of: expected, separatedBy: "merge_group").count == 2)
    }

    /// A direct-form caller carrying the merge_group trigger parses: the
    /// trigger block is host state `Parse` deliberately does not model,
    /// and must not refuse.
    @Test
    func `parse accepts a caller carrying the merge group trigger`() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-bool-primitives",
            layer: .primitives
        )
        let rendered = Institute.Repository.Policy.Caller.Render.direct(caller)
        let withTrigger = CallerFoundation.replacingOccurrences(
            in: rendered,
            of: "  workflow_dispatch:",
            with: "  merge_group:\n    types:\n      - checks_requested\n  workflow_dispatch:"
        )
        #expect(withTrigger != rendered)
        let parsed = try Institute.Repository.Policy.Caller.Parse.caller(
            withTrigger,
            repository: caller.repository
        )
        #expect(parsed == caller)
    }

    @Test
    func `terminal form is one byte-identical caller`() throws {
        let expected = Institute.Repository.Policy.Caller.Render.terminal
        #expect(expected.hasSuffix("\n"))
        #expect(expected.contains("  ci:\n    if: ${{ !github.event.repository.private }}"))
        #expect(expected.contains("    name: ci / matrix"))
        #expect(
            expected.contains(
                "    uses: swift-institute/.github/.github/workflows/swift-ci.yml@main"
            )
        )
        #expect(!expected.contains("with:"))
        #expect(!expected.contains("secrets:"))
        #expect(!expected.contains("notify-linter-republish"))
        #expect(!expected.contains("tags:"))

        for layer in Institute.Repository.Policy.Caller.Layer.allCases {
            let caller = try Institute.Repository.Policy.Caller(
                repository: "\(layer.wrapperOrganization)/swift-example",
                layer: layer,
                inputs: [(key: "platform-support", value: "windows")]
            )
            #expect(Institute.Repository.Policy.Caller.Render.terminal == expected)
            #expect(!Institute.Repository.Policy.Caller.Render.terminal.contains(caller.repository))
        }
    }

    @Test
    func currentFormMatchesIncumbentShape() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-bool-primitives",
            layer: .primitives
        )
        let text = Institute.Repository.Policy.Caller.Render.current(caller)
        #expect(text.contains("uses: swift-primitives/.github/.github/workflows/swift-ci.yml@main"))
        #expect(text.contains("secrets: inherit"))
        #expect(text.contains("tags:\n      - '*'"))
        #expect(text.hasSuffix("\n"))
        #expect(!text.contains("with:"))
    }

    @Test
    func crossOrgCurrentFormForwardsLegacyFourSecrets() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-ietf/swift-rfc-2045",
            layer: .standards,
            inputs: [(key: "platform-support", value: "macos-linux")]
        )
        let text = Institute.Repository.Policy.Caller.Render.current(caller)
        #expect(text.contains("uses: swift-standards/.github/.github/workflows/swift-ci.yml@main"))
        #expect(!text.contains("secrets: inherit"))
        for name in Institute.Repository.Policy.Caller.legacySecretNames {
            #expect(text.contains("      \(name): ${{ secrets.\(name) }}"))
        }
        #expect(text.contains("    with:\n      platform-support: macos-linux"))
    }

    @Test
    func inputsEmitInCanonicalOrderRegardlessOfSpecOrder() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-foundations/swift-demo",
            layer: .institute,
            inputs: [
                (key: "docs-umbrella-module", value: "Demo"),
                (key: "swift-version", value: "6.2"),
            ]
        )
        let text = Institute.Repository.Policy.Caller.Render.current(caller)
        let swiftVersion = try #require(CallerFoundation.range(of: "swift-version: 6.2", in: text))
        let docs = try #require(CallerFoundation.range(of: "docs-umbrella-module: Demo", in: text))
        #expect(swiftVersion.lowerBound < docs.lowerBound)
    }

    @Test
    func `tier scheduling customization round trips`() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-institute/institute-continuous-integration",
            layer: .institute,
            inputs: [(key: "tier", value: "build")]
        )
        let text = Institute.Repository.Policy.Caller.Render.direct(caller)
        #expect(text.contains("      tier: build"))

        let parsed = try Institute.Repository.Policy.Caller.Parse.caller(
            text,
            repository: caller.repository
        )
        #expect(parsed.inputs.map(\.key) == caller.inputs.map(\.key))
        #expect(parsed.inputs.map(\.value) == caller.inputs.map(\.value))
    }

    @Test
    func directFormHasNoTagTriggerAndCallsUniversal() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-bool-primitives",
            layer: .primitives
        )
        let text = Institute.Repository.Policy.Caller.Render.direct(caller)
        #expect(!text.contains("tags:"))
        #expect(text.contains("uses: swift-institute/.github/.github/workflows/swift-ci.yml@main"))
        #expect(!text.contains("secrets"))
        // K-12 property transfer: the layer's lint bundle rides the leaf.
        #expect(text.contains("    with:\n      lint-bundle: primitives"))
        // R-08 context preservation: the dead wrapper hop's display
        // segment rides the job name, keeping `ci / matrix / <job>`.
        #expect(
            text.contains(
                "  ci:\n    if: ${{ !github.event.repository.private }}\n    name: ci / matrix\n    uses:"
            )
        )
        let withSecrets = Institute.Repository.Policy.Caller.Render.direct(
            caller,
            privateDependencyClosure: true
        )
        #expect(
            withSecrets.contains(
                "      SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY }}"
            )
        )
        #expect(!withSecrets.contains("PRIVATE_REPO_TOKEN"))
        #expect(!withSecrets.contains("secrets: inherit"))
    }

    /// Visibility gate (#358 comment 5205099233): the terminal caller is
    /// one uniform artifact for public and private repositories alike,
    /// and privacy is expressed by a gate rather than by per-repository
    /// provisioning. EVERY job of the direct form must carry it — a
    /// renderer that gated only the `ci` job would still emit valid YAML
    /// and still pass every other test in this suite, so the assertion is
    /// made over the parsed job set rather than over one known job id.
    @Test
    func everyDirectFormJobCarriesTheVisibilityGate() throws {
        let gate = "!github.event.repository.private"
        var corpus: [String] = []
        for layer in Institute.Repository.Policy.Caller.Layer.allCases {
            let ordinary = try Institute.Repository.Policy.Caller(
                repository: "\(layer.wrapperOrganization)/swift-demo",
                layer: layer
            )
            corpus.append(Institute.Repository.Policy.Caller.Render.direct(ordinary))
            corpus.append(
                Institute.Repository.Policy.Caller.Render.direct(
                    ordinary,
                    privateDependencyClosure: true
                )
            )
        }
        for repository in Institute.Repository.Policy.Caller.linterRulePackRepositories {
            let layer: Institute.Repository.Policy.Caller.Layer =
                repository.hasPrefix("swift-primitives/")
                ? .primitives
                : repository.hasPrefix("swift-standards/") ? .standards : .institute
            corpus.append(
                Institute.Repository.Policy.Caller.Render.direct(
                    try Institute.Repository.Policy.Caller(repository: repository, layer: layer)
                )
            )
        }

        var totalJobs = 0
        for text in corpus {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let jobsIndex = try #require(lines.firstIndex(of: "jobs:"))
            var current: (id: Substring, gated: Bool)?
            var jobs: [(id: Substring, gated: Bool)] = []
            for line in lines[lines.index(after: jobsIndex)...] {
                if line.hasPrefix("  ") && !line.hasPrefix("    ") && line.hasSuffix(":") {
                    if let job = current { jobs.append(job) }
                    current = (id: line.dropFirst(2).dropLast(), gated: false)
                } else if line.contains(gate) {
                    current?.gated = true
                }
            }
            if let job = current { jobs.append(job) }

            // Positive control: the parse found jobs at all, so a clean
            // sweep below is a measurement and not an empty corpus.
            #expect(!jobs.isEmpty)
            #expect(jobs.contains { $0.id == "ci" })
            totalJobs += jobs.count
            for job in jobs {
                #expect(job.gated, "job \(job.id) is not visibility-gated")
            }
        }
        // Absence control on the parser itself: the rule-pack leaf really
        // does contribute a second job, so `jobs` above is not always a
        // one-element list that a `ci`-only gate would satisfy.
        #expect(totalJobs > corpus.count)
    }

    /// The gate belongs to the terminal (`direct`) form only. `current`
    /// is held at byte parity with the incumbent generator by the F3
    /// fixture corpus, so it must NOT acquire the gate.
    @Test
    func parityFormDoesNotCarryTheVisibilityGate() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-bool-primitives",
            layer: .primitives
        )
        #expect(
            !Institute.Repository.Policy.Caller.Render.current(caller)
                .contains("github.event.repository.private")
        )
    }

    @Test
    func directFormTransfersEachLayersLintBundle() throws {
        for (layer, bundle) in [
            (Institute.Repository.Policy.Caller.Layer.primitives, "primitives"),
            (.standards, "standards"),
            (.institute, "institute"),
        ] {
            let caller = try Institute.Repository.Policy.Caller(
                repository: "\(layer.wrapperOrganization)/swift-demo",
                layer: layer
            )
            let text = Institute.Repository.Policy.Caller.Render.direct(caller)
            #expect(text.contains("      lint-bundle: \(bundle)"))
        }
        // Caller inputs follow the layer-owned line in canonical order.
        let withInputs = try Institute.Repository.Policy.Caller(
            repository: "swift-standards/swift-demo",
            layer: .standards,
            inputs: [(key: "platform-support", value: "macos-linux")]
        )
        let text = Institute.Repository.Policy.Caller.Render.direct(withInputs)
        #expect(
            text.contains(
                "    with:\n      lint-bundle: standards\n      platform-support: macos-linux"
            )
        )
    }

    @Test
    func rulePackRepositoriesCarryTheNotifyJob() throws {
        for repository in Institute.Repository.Policy.Caller.linterRulePackRepositories {
            let layer: Institute.Repository.Policy.Caller.Layer =
                repository.hasPrefix("swift-primitives/")
                ? .primitives
                : repository.hasPrefix("swift-standards/") ? .standards : .institute
            let caller = try Institute.Repository.Policy.Caller(repository: repository, layer: layer)
            let text = Institute.Repository.Policy.Caller.Render.direct(caller)
            #expect(text.contains("  notify-linter-republish:"))
            #expect(
                text.contains(
                    "if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main'"
                        + " && !github.event.repository.private }}"
                )
            )
            #expect(
                text.contains(
                    "uses: swift-institute/.github/.github/workflows/notify-linter-republish.yml@main"
                )
            )
            #expect(
                text.contains(
                    "      SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY }}"
                )
            )
            #expect(!text.contains("SWIFT_INSTITUTE_BOT_APP_CLIENT_ID"))
        }
    }

    @Test
    func ordinaryRepositoriesDoNotCarryTheNotifyJob() throws {
        let caller = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-bool-primitives",
            layer: .primitives
        )
        #expect(!Institute.Repository.Policy.Caller.Render.direct(caller).contains("notify-linter-republish"))
        // Near miss: a similarly named repo NOT in the exact-coordinate set.
        let nearMiss = try Institute.Repository.Policy.Caller(
            repository: "swift-primitives/swift-linter-rules-tools",
            layer: .primitives
        )
        #expect(
            !Institute.Repository.Policy.Caller.Render.direct(nearMiss).contains("notify-linter-republish")
        )
    }

    /// F14 cutover: the App id is a variable, never a forwarded secret.
    /// The near-miss half matters more than the positive half — a
    /// renderer that regressed to the historical two-secret spelling
    /// would still emit valid YAML and still pass every other test here.
    @Test
    func terminalProfileForwardsOnlyThePrivateKeyAndNeverTheId() throws {
        #expect(
            Institute.Repository.Policy.Caller.terminalSecretNames == [
                "SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY"
            ]
        )
        #expect(
            Institute.Repository.Policy.Caller.terminalVariableNames == [
                "SWIFT_INSTITUTE_BOT_APP_ID"
            ]
        )
        // The two sets are disjoint: no name may be both.
        for name in Institute.Repository.Policy.Caller.terminalVariableNames {
            #expect(!Institute.Repository.Policy.Caller.terminalSecretNames.contains(name))
        }

        // No rendered form may name an id-shaped secret. Checked over
        // every layer and over both the ordinary and the rule-pack leaf,
        // with and without the private dependency closure.
        var rendered: [String] = []
        for layer in Institute.Repository.Policy.Caller.Layer.allCases {
            let ordinary = try Institute.Repository.Policy.Caller(
                repository: "\(layer.wrapperOrganization)/swift-demo",
                layer: layer
            )
            rendered.append(Institute.Repository.Policy.Caller.Render.direct(ordinary))
            rendered.append(
                Institute.Repository.Policy.Caller.Render.direct(
                    ordinary,
                    privateDependencyClosure: true
                )
            )
        }
        for repository in Institute.Repository.Policy.Caller.linterRulePackRepositories {
            let layer: Institute.Repository.Policy.Caller.Layer =
                repository.hasPrefix("swift-primitives/")
                ? .primitives
                : repository.hasPrefix("swift-standards/") ? .standards : .institute
            rendered.append(
                Institute.Repository.Policy.Caller.Render.direct(
                    try Institute.Repository.Policy.Caller(repository: repository, layer: layer)
                )
            )
        }

        // Positive control: the corpus is non-empty and does contain the
        // one name that IS expected, so a zero below is a measurement.
        #expect(!rendered.isEmpty)
        #expect(
            rendered.contains {
                $0.contains("SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY")
            }
        )

        for text in rendered {
            #expect(!text.contains("secrets.SWIFT_INSTITUTE_BOT_APP_ID"))
            #expect(!text.contains("SWIFT_INSTITUTE_BOT_APP_CLIENT_ID"))
            #expect(!text.contains("PRIVATE_REPO_TOKEN"))
            #expect(!text.contains("secrets: inherit"))
            // The id is not delivered by the leaf at all — not as a
            // secret and not as a caller-side `vars` forward. It is
            // resolved inside the callee from the org variable.
            #expect(!text.contains("SWIFT_INSTITUTE_BOT_APP_ID"))
        }
    }

    @Test
    func malformedRepositoryRefuses() {
        #expect(throws: Institute.Repository.Policy.Caller.Error.self) {
            try Institute.Repository.Policy.Caller(repository: "no-slash", layer: .primitives)
        }
    }
}
