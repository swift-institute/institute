public import Institute_Model
import Institute_CI_Model
import Testing

@Suite
struct ContinuousIntegrationPlanTests {
    @Test
    func ordinaryPushSelectsBuildTierWithLinuxPrimary() throws {
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/feature",
            event: "push",
            lintBundle: "standards"
        )
        #expect(plan.tier == .build)
        #expect(plan.legs.map(\.id) == ["source", "linux-release", "linux-6-4"])
        #expect(plan.gating.map(\.id) == ["source", "linux-release"])
    }

    @Test
    func tagRefAndDispatchAndMainForceFullTier() throws {
        for (ref, event) in [
            ("refs/tags/1.0.0", "push"),
            ("refs/heads/x", "workflow_dispatch"),
            ("refs/heads/main", "push"),
        ] {
            let plan = try Institute.CI.Plan(ref: ref, event: event, lintBundle: "institute")
            #expect(plan.tier == .full, "\(ref)/\(event)")
        }
    }

    @Test
    func commitTokensSteerTier() throws {
        #expect(
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                headMessage: "wip [ci full]",
                event: "push",
                lintBundle: "standards"
            ).tier == .full
        )
        #expect(
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                headMessage: "wip [ci build]",
                event: "workflow_dispatch",
                lintBundle: "standards"
            ).tier == .build
        )
    }

    @Test
    func retiredLintTierRefuses() {
        #expect(throws: Institute.CI.Plan.Error.retiredLintTier) {
            try Institute.CI.Plan(
                forcedTier: "lint",
                ref: "refs/heads/x",
                event: "push",
                lintBundle: "standards"
            )
        }
    }

    @Test
    func platformSupportValidation() {
        #expect(throws: Institute.CI.Plan.Error.invalidPlatformFamily("mac")) {
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                event: "push",
                platformSupport: "mac",
                lintBundle: "standards"
            )
        }
        #expect(throws: Institute.CI.Plan.Error.duplicatePlatformFamily("linux")) {
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                event: "push",
                platformSupport: "linux,linux",
                lintBundle: "standards"
            )
        }
        #expect(throws: Institute.CI.Plan.Error.trailingEmptyPlatformFamily("linux,")) {
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                event: "push",
                platformSupport: "linux,",
                lintBundle: "standards"
            )
        }
        #expect(throws: Institute.CI.Plan.Error.invalidPlatformFamily("")) {
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                event: "push",
                platformSupport: ",linux",
                lintBundle: "standards"
            )
        }
    }

    @Test
    func buildTierPrimarySelectionFollowsPriority() throws {
        #expect(
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                event: "push",
                platformSupport: "windows,apple",
                lintBundle: "standards"
            ).legs.map(\.id).contains("windows-release")
        )
        let appleOnly = try Institute.CI.Plan(
            ref: "refs/heads/x",
            event: "push",
            platformSupport: "apple",
            lintBundle: "standards"
        )
        #expect(appleOnly.legs.map(\.id) == ["source", "macos-release"])
    }

    @Test
    func fullTierPlatformFilterNarrowsLegs() throws {
        let plan = try Institute.CI.Plan(
            forcedTier: "full",
            ref: "refs/heads/x",
            event: "push",
            platformSupport: "linux",
            lintBundle: "standards"
        )
        #expect(!plan.legs.map(\.id).contains("macos-release"))
        #expect(!plan.legs.map(\.id).contains("windows-release"))
        #expect(plan.legs.map(\.id).contains("linux-release"))
        #expect(plan.legs.map(\.id).contains("linux-6-4"))
    }

    @Test
    func theExhaustiveTierIsPlatformFilteredLikeAnyOther() throws {
        // Opt-in does not exempt a leg from platform identity: a package
        // whose specification excludes Apple does not gain an Apple leg by
        // asking for everything.
        let plan = try Institute.CI.Plan(
            forcedTier: "exhaustive",
            ref: "refs/heads/x",
            event: "push",
            platformSupport: "linux",
            lintBundle: "standards"
        )
        #expect(!plan.legs.map(\.id).contains("apple-simulator-build"))
        #expect(plan.legs.map(\.id).contains("linux-nightly"))
    }

    @Test
    func primitivesBundleAppendsAdvisoryLegsInBothTiers() throws {
        for tier in ["build", "full"] {
            let plan = try Institute.CI.Plan(
                forcedTier: tier,
                ref: "refs/heads/x",
                event: "push",
                lintBundle: "primitives"
            )
            #expect(plan.legs.map(\.id).contains("embedded"), Comment(rawValue: tier))
            #expect(!plan.gating.map(\.id).contains("embedded"), Comment(rawValue: tier))
        }
    }

    @Test
    func invalidLintBundleRefuses() {
        #expect(throws: Institute.CI.Plan.Error.invalidLintBundle("web")) {
            try Institute.CI.Plan(ref: "refs/heads/x", event: "push", lintBundle: "web")
        }
    }

    @Test
    func noAutomaticPathReachesTheExhaustiveTier() throws {
        // The whole point of the tier: cost-bearing advisory legs must not
        // ride an ordinary push, a pull request, a dispatch, or a merge.
        for (ref, event) in [
            ("refs/heads/feature", "push"),
            ("refs/heads/feature", "pull_request"),
            ("refs/heads/feature", "workflow_dispatch"),
            ("refs/heads/main", "push"),
            ("refs/tags/1.0.0", "push"),
        ] {
            let plan = try Institute.CI.Plan(
                ref: ref,
                event: event,
                lintBundle: "primitives"
            )
            #expect(plan.tier != .exhaustive, Comment(rawValue: "\(ref)/\(event)"))
            let ids = Set(plan.legs.map(\.id))
            for opt in [
                "linux-nightly", "apple-simulator-build", "embedded-wasm-sdk",
                "android-build", "static-linux-musl-build",
            ] {
                #expect(!ids.contains(opt), Comment(rawValue: "\(ref)/\(event): \(opt)"))
            }
        }
    }

    @Test
    func exhaustiveTierIsReachedOnlyByAsking() throws {
        for plan in [
            try Institute.CI.Plan(
                forcedTier: "exhaustive",
                ref: "refs/heads/x",
                event: "push",
                lintBundle: "primitives"
            ),
            try Institute.CI.Plan(
                ref: "refs/heads/x",
                headMessage: "wip [ci exhaustive]",
                event: "push",
                lintBundle: "primitives"
            ),
        ] {
            #expect(plan.tier == .exhaustive)
            #expect(
                Set(plan.legs.map(\.id)).isSuperset(of: [
                    "linux-nightly", "apple-simulator-build", "embedded-wasm-sdk",
                    "android-build", "static-linux-musl-build",
                ])
            )
        }
    }

    @Test
    func theIntegrationRefNeverDowngradesAnExhaustiveRequest() throws {
        // main promotes unconditionally, but promotion must not narrow.
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/main",
            headMessage: "[ci exhaustive]",
            event: "push",
            lintBundle: "institute"
        )
        #expect(plan.tier == .exhaustive)
    }

    @Test
    func embeddedStaysOnEveryTierForPrimitives() throws {
        // The L1 freestanding invariant is not a cost knob.
        for tier in ["build", "full", "exhaustive"] {
            let plan = try Institute.CI.Plan(
                forcedTier: tier,
                ref: "refs/heads/x",
                event: "push",
                lintBundle: "primitives"
            )
            #expect(plan.legs.map(\.id).contains("embedded"), Comment(rawValue: tier))
        }
    }

    @Test
    func unchangedPackageContentDropsEveryPackageWorkLeg() throws {
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/main",
            event: "push",
            lintBundle: "primitives",
            packageContentChanged: false
        )
        #expect(!plan.packageContentChanged)
        let ids = Set(plan.legs.map(\.id))
        for dropped in [
            "linux-release", "macos-release", "windows-release", "linux-6-4",
            "linux-nightly", "apple-simulator-build", "embedded",
            "embedded-wasm-sdk", "android-build", "static-linux-musl-build",
        ] {
            #expect(!ids.contains(dropped), Comment(rawValue: dropped))
        }
        // The quality gates and the aggregate's own surface survive: the
        // narrowing is of package work, not of the run.
        #expect(ids.contains("source"))
    }

    @Test
    func unchangedPackageContentStandsDownTheBuildLegGuard() throws {
        // With every build leg dropped the guard would otherwise refuse the
        // plan; building nothing is the planned outcome here, not a green
        // over nothing, so it must stand down rather than throw.
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/x",
            event: "push",
            platformSupport: "linux",
            lintBundle: "standards",
            packageContentChanged: false
        )
        #expect(!plan.gating.contains { $0.buildLeg })
    }

    @Test
    func dispatchOverridesAnUnchangedContentClassification() throws {
        // An explicit dispatch is a deliberate request to verify.
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/x",
            event: "workflow_dispatch",
            lintBundle: "standards",
            packageContentChanged: false
        )
        #expect(plan.packageContentChanged)
        #expect(plan.legs.contains { $0.buildLeg })
    }

    @Test
    func deschedulingRemovesTheLegAndRecordsTheReason() throws {
        let plan = try Institute.CI.Plan(
            forcedTier: "exhaustive",
            ref: "refs/heads/main",
            event: "push",
            lintBundle: "institute",
            deschedule: ["linux-nightly": "nightly-exception-expired"]
        )
        #expect(!plan.legs.map(\.id).contains("linux-nightly"))
        #expect(
            plan.descheduled == [
                .init(
                    leg: Institute.CI.Leg("linux-nightly"),
                    reason: "nightly-exception-expired"
                )
            ]
        )
    }

    @Test
    func deschedulingALegThisRunNeverSelectedRecordsNothing() throws {
        // Absent is not descheduled. The build tier never selects
        // apple-simulator-build, so a record naming it would assert a
        // removal that did not happen.
        let plan = try Institute.CI.Plan(
            ref: "refs/heads/x",
            event: "push",
            lintBundle: "standards",
            deschedule: ["apple-simulator-build": "some-reason"]
        )
        #expect(plan.descheduled.isEmpty)
    }
}

@Suite
struct ContinuousIntegrationAggregateTests {
    static let participants = [
        "macos-release", "linux-release", "windows-release",
        "source",
    ]

    func needs(_ overrides: [String: String]) -> [String: String] {
        var results: [String: String] = [:]
        for job in Self.participants { results[job] = overrides[job] ?? "skipped" }
        return results
    }

    @Test
    func selectedTierPasses() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
            ]),
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false
        )
        #expect(verdict.pass)
        #expect(verdict.built == ["linux-release"])
    }

    @Test
    func skippedGatingLegFails() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "skipped", "linux-release": "success",
            ]),
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false
        )
        #expect(!verdict.pass)
        #expect(
            verdict.findings.contains(
                .selectedLegNotSuccessful(job: "source", result: "skipped")
            )
        )
    }

    @Test
    func unselectedLegThatRanFails() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
                "macos-release": "success",
            ]),
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false
        )
        #expect(!verdict.pass)
        #expect(
            verdict.findings.contains(
                .unselectedLegRan(job: "macos-release", result: "success")
            )
        )
    }

    @Test
    func planFailureEmptyGatingEmptySubjectAllFail() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "failure",
            results: needs([:]),
            gating: [],
            subjectRepository: "",
            subjectSha: "",
            tier: "",
            requireFullTier: false
        )
        #expect(!verdict.pass)
        #expect(verdict.findings.contains(.planDidNotSucceed(result: "failure")))
        #expect(verdict.findings.contains(.emptyGating))
        #expect(verdict.findings.contains(.emptySubject))
        #expect(verdict.findings.contains(.nothingBuilt))
    }

    @Test
    func mainRequiresFullTier() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
            ]),
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: true
        )
        #expect(!verdict.pass)
        #expect(verdict.findings.contains(.fullTierRequired(got: "build")))
    }

    @Test
    func lintOnlySuccessWithoutBuildFails() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success",
            ]),
            gating: ["source"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false
        )
        #expect(!verdict.pass)
        #expect(verdict.findings.contains(.nothingBuilt))
    }

    @Test
    func descheduledLegThatRanFails() {
        // The descheduling record and the execution graph disagree: the
        // plan said this leg would not run, and it did.
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
            ])
            .merging(["linux-nightly": "failure"]) { _, new in new },
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false,
            descheduled: ["linux-nightly"]
        )
        #expect(!verdict.pass)
        #expect(
            verdict.findings.contains(
                .descheduledLegRan(job: "linux-nightly", result: "failure")
            )
        )
    }

    @Test
    func descheduledGatingLegIsRefused() {
        // Advisory-class descheduling must never account for a gating
        // obligation, whatever the caller's policy claims.
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
            ]),
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false,
            descheduled: ["windows-release"]
        )
        #expect(!verdict.pass)
        #expect(verdict.findings.contains(.descheduledGatingLeg(job: "windows-release")))
    }

    @Test
    func descheduledLegThatSkippedIsAccountedFor() {
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success", "linux-release": "success",
            ])
            .merging(["linux-nightly": "skipped"]) { _, new in new },
            gating: ["source", "linux-release"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false,
            descheduled: ["linux-nightly"]
        )
        #expect(verdict.pass)
    }

    @Test
    func unchangedPackageContentSuppressesNothingBuilt() {
        // The one case where building nothing is the planned outcome.
        let verdict = Institute.CI.AggregateVerdict(
            planResult: "success",
            results: needs([
                "source": "success",
            ]),
            gating: ["source"],
            subjectRepository: "o/r",
            subjectSha: "abc",
            tier: "build",
            requireFullTier: false,
            packageContentChanged: false
        )
        #expect(verdict.pass)
        #expect(!verdict.findings.contains(.nothingBuilt))
    }

    @Test
    func requirementTablePreservesCheckContext() {
        #expect(Institute.CI.Requirement.checkContext == "ci / matrix / ci-ok")
        let table = Institute.CI.Requirement.table(
            participants: ["plan"] + Self.participants,
            gating: [Institute.CI.Leg("source"), Institute.CI.Leg("linux-release")]
        )
        #expect(table.count == 6)
        #expect(table.first { $0.job == "source" }?.expectation == .success)
        #expect(table.first { $0.job == "macos-release" }?.expectation == .skipped)
    }
}
