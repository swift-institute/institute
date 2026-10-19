import Byte
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy Tests` {
    @Test
    func eligibilityFixtures() throws {
        let url = try #require(RepositoryPolicyFoundation.url(forResource: "eligibility", withExtension: "json"))
        let fixtures = try RepositoryPolicyFoundation.decode([Fixture].self, contentsOf: url)

        #expect(fixtures.count == 9)
        for fixture in fixtures {
            let state = fixture.pvr.flatMap(Institute.Repository.Policy.VulnerabilityReporting.init(rawValue:))
            let decision = Institute.Repository.Policy.decision(
                for: fixture.repository,
                manifestKind: fixture.manifestKind,
                vulnerabilityReporting: state
            )
            #expect(render(decision) == fixture.decision, "\(fixture.name)")
        }
    }

    // The canonical policy contracts ride along as test fixtures; the
    // live documents are supplied by the control-plane workflows.
    private func policy(_ name: String) throws -> [Byte] {
        let url = try #require(RepositoryPolicyFoundation.url(forResource: name, withExtension: "json"))
        return try RepositoryPolicyFoundation.bytes(contentsOf: url)
    }

    private func policyText(_ name: String) throws -> String {
        String(decoding: try policy(name), as: UTF8.self)
    }

    @Test
    func protectedMainRulesetFixtureDefinesThePRTransaction() throws {
        let payload = try Institute.Repository.Policy.Ruleset.protectedMainPayload(
            from: try policy("protected-main-ruleset")
        )
        let object = try #require(try RepositoryPolicyFoundation.jsonObject(with: payload.map { $0.underlying }) as? [String: Any])
        #expect((object["bypass_actors"] as? [Any])?.isEmpty == true)
        #expect((object["enforcement"] as? String) == "active")
        let rules = try #require(object["rules"] as? [[String: Any]])
        let review = try #require(
            rules.first(where: { $0["type"] as? String == "pull_request" })?["parameters"]
                as? [String: Any]
        )
        let checks = try #require(
            rules.first(where: { $0["type"] as? String == "required_status_checks" })?["parameters"]
                as? [String: Any]
        )
        // Pre-release posture (ICI#35 adjudication 2026-08-14): no approval
        // gate; the release re-arm restores 1/true.
        #expect(review["required_approving_review_count"] as? Int == 0)
        #expect(review["require_last_push_approval"] as? Bool == false)
        #expect(review["dismiss_stale_reviews_on_push"] as? Bool == true)
        // GitHub's PR gate rejects unresolved conversations and a non-current
        // check; the caller-path-prefixed `ci / matrix / ci-ok` aggregate is
        // the one required current-head status, as rendered on live package
        // PR heads (renamed from `ci / ci-ok` — swift-institute/.github#276
        // Task 3-01).
        #expect(review["required_review_thread_resolution"] as? Bool == true)
        // GitHub server-canonicalizes allowed_merge_methods,
        // dismissal_restriction, and required_reviewers onto every
        // pull_request rule even when the contract omits them
        // (swift-institute/.github#196); the contract now pins all three
        // explicitly so the applied ruleset's read-back stays in exact
        // correspondence, and squash-only merge policy is an enforced fact
        // rather than an unpinned server default.
        #expect(review["allowed_merge_methods"] as? [String] == ["squash"])
        #expect((review["required_reviewers"] as? [Any])?.isEmpty == true)
        let dismissalRestriction = try #require(
            review["dismissal_restriction"] as? [String: Any]
        )
        #expect(dismissalRestriction["enabled"] as? Bool == false)
        #expect((dismissalRestriction["allowed_actors"] as? [Any])?.isEmpty == true)
        #expect(checks["strict_required_status_checks_policy"] as? Bool == true)
        let required = try #require(checks["required_status_checks"] as? [[String: Any]])
        #expect(required.count == 1)
        #expect(required.first?["context"] as? String == "ci / matrix / ci-ok")
    }

    // Positive control: the now-retired temporary compatibility context
    // `ci / ci-ok` is no longer, alone, the target public contract — a
    // payload requiring only it would gate main on a layer wrapper's
    // temporary aggregate that Task 3-02 step 7 deletes. The validator must
    // refuse it (swift-institute/.github#276 Task 3-01, renamed from the
    // bare-legacy-name positive control this replaces).
    @Test
    func protectedMainPayloadRejectsTheRetiredCompatibilityContextAlone() throws {
        let legacy = try RepositoryPolicyFoundation.substitute(
            of: "\"context\": \"ci / matrix / ci-ok\"",
            with: "\"context\": \"ci / ci-ok\"",
            in: policyText("protected-main-ruleset")
        )
        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: [Byte](utf8: legacy))
        }
    }

    // Positive control: the retired bare `ci-ok` context (no caller-path
    // prefix at all) is a name no caller path has ever rendered, so a
    // payload requiring it would gate main on a check that can never
    // report. The validator must refuse it.
    @Test
    func protectedMainPayloadRejectsTheBareUnprefixedContext() throws {
        let legacy = try RepositoryPolicyFoundation.substitute(
            of: "\"context\": \"ci / matrix / ci-ok\"",
            with: "\"context\": \"ci-ok\"",
            in: policyText("protected-main-ruleset")
        )
        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: [Byte](utf8: legacy))
        }
    }

    // MARK: - Bypass prohibition (TX5, swift-institute/.github#276)

    // Serializes `object` to policy bytes. Used by the bypass negative
    // controls below, which need a payload that differs from a shipped
    // fixture in exactly one field.
    private func scratchFixture(_ object: [String: Any]) throws -> [Byte] {
        try RepositoryPolicyFoundation.data(withJSONObject: object)
    }

    // Discriminating negative: no payload class admits a bypass actor. The
    // retired R28.1 programme window's actor (the swift-institute-bot App,
    // `always` mode) is refused on every class — the standing contract is
    // "no bypass actor at all".
    @Test
    func everyPayloadClassRefusesAnyBypassActor() throws {
        let authorized = [
            ["actor_id": 3_543_256, "actor_type": "Integration", "bypass_mode": "always"]
        ]
        for fixture in [
            "protected-main-ruleset",
            "protected-main-private-ruleset",
            "protected-main-control-ruleset",
        ] {
            let source = try policy(fixture)
            var object = try #require(
                try RepositoryPolicyFoundation.jsonObject(with: source.map { $0.underlying }) as? [String: Any]
            )
            object["bypass_actors"] = authorized
            let url = try scratchFixture(object)
            #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
                if fixture.contains("control") {
                    _ = try Institute.Repository.Policy.Ruleset.protectedMainControlPayload(from: url)
                } else if fixture.contains("private") {
                    _ = try Institute.Repository.Policy.Ruleset.protectedMainPrivatePayload(from: url)
                } else {
                    _ = try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
                }
            }
        }
    }

    // MARK: - Private ruleset contract (Task 2-01/2-02, #253; Task 3-01)

    // Positive control: the private fixture requires exactly `verification /
    // workspace` — the trusted control-plane receipt — and nothing else. No
    // compatibility variant exists: no producer preceded it.
    @Test
    func protectedMainPrivatePayloadFixtureRequiresWorkspaceVerification() throws {
        let url = try policy("protected-main-private-ruleset")
        let payload = try Institute.Repository.Policy.Ruleset.protectedMainPrivatePayload(from: url)
        let object = try #require(try RepositoryPolicyFoundation.jsonObject(with: payload.map { $0.underlying }) as? [String: Any])
        let rules = try #require(object["rules"] as? [[String: Any]])
        let checks = try #require(
            rules.first(where: { $0["type"] as? String == "required_status_checks" })?[
                "parameters"
            ] as? [String: Any]
        )
        let required = try #require(checks["required_status_checks"] as? [[String: Any]])
        #expect(required.count == 1)
        #expect(required.first?["context"] as? String == "verification / workspace")
    }

    // Discriminating negative: the private validator must refuse the public
    // final fixture (wrong context), and the public final validator must
    // refuse the private fixture — visibility selects a genuinely different
    // required context, not an interchangeable label.
    @Test
    func protectedMainPrivateAndPublicPayloadsRejectEachOthersFixture() throws {
        let publicFixture = try policy("protected-main-ruleset")
        let privateFixture = try policy("protected-main-private-ruleset")
        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPrivatePayload(from: publicFixture)
        }
        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: privateFixture)
        }
    }

    // Positive control: a payload carrying a required-status-checks rule
    // missing entirely is refused by every package-class validator alike —
    // isolates the shared rule-completeness check from the per-variant
    // context-set check.
    @Test
    func everyPackageVariantRejectsAPayloadMissingTheRequiredStatusChecksRule() throws {
        let canonical = try policy("protected-main-ruleset")
        var object = try #require(
            try RepositoryPolicyFoundation.jsonObject(with: canonical.map { $0.underlying }) as? [String: Any]
        )
        var rules = try #require(object["rules"] as? [[String: Any]])
        rules.removeAll { $0["type"] as? String == "required_status_checks" }
        object["rules"] = rules
        let url = try scratchFixture(object)

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
        }
        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPrivatePayload(from: url)
        }
    }

    // Positive control: GitHub's read-back carries additional top-level
    // server metadata (id, node_id, source_type, timestamps) the contract
    // never emits (swift-institute/.github#196). Once the pull_request
    // parameters carry the exact pinned shape, that additive metadata must
    // not fail validation — the read-back comparison in sync-metadata.yml's
    // `rulesets` job only needs the pinned fields, not byte-identical
    // top-level shape.
    @Test
    func protectedMainPayloadAcceptsACanonicalReadbackAroundThePinnedContract() throws {
        let canonical = try policy("protected-main-ruleset")
        var object = try #require(
            try RepositoryPolicyFoundation.jsonObject(with: canonical.map { $0.underlying }) as? [String: Any]
        )
        object["id"] = 20_244_631
        object["node_id"] = "RUL_lADummyReadback"
        object["source_type"] = "Repository"
        object["created_at"] = "2026-08-02T00:00:00Z"
        object["updated_at"] = "2026-08-02T00:00:00Z"
        let url = try scratchFixture(object)

        let payload = try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
        let decoded = try #require(
            try RepositoryPolicyFoundation.jsonObject(with: payload.map { $0.underlying }) as? [String: Any]
        )
        let rules = try #require(decoded["rules"] as? [[String: Any]])
        let review = try #require(
            rules.first(where: { $0["type"] as? String == "pull_request" })?["parameters"]
                as? [String: Any]
        )
        #expect(review["allowed_merge_methods"] as? [String] == ["squash"])
    }

    // Discriminating negative: GitHub's server-default merge-method set —
    // all three methods — must be rejected. Institute policy is
    // squash-only; a contract or read-back carrying the wider set is a
    // policy weakening (swift-institute/.github#196), not normalization
    // drift, so it must fail closed rather than pass as "close enough".
    @Test
    func protectedMainPayloadRejectsAllMergeMethods() throws {
        let canonical = try policy("protected-main-ruleset")
        let allMethods = RepositoryPolicyFoundation.substitute(
            of: "\"allowed_merge_methods\": [\"squash\"]",
            with: "\"allowed_merge_methods\": [\"merge\", \"squash\", \"rebase\"]",
            in: String(decoding: canonical, as: UTF8.self)
        )
        #expect(allMethods.contains("\"merge\", \"squash\", \"rebase\""))
        let url = [Byte](utf8: allMethods)

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
        }
    }

    // Discriminating negative: the pre-fix contract shape — silent on
    // allowed_merge_methods, dismissal_restriction, and required_reviewers —
    // must be rejected going forward (swift-institute/.github#196), even
    // though GitHub itself accepts it and silently canonicalizes a weaker
    // merge-method default over it.
    @Test
    func protectedMainPayloadRejectsAnUnpinnedMergeMethodContract() throws {
        let canonical = try policy("protected-main-ruleset")
        let unpinned = RepositoryPolicyFoundation.substitute(
            of: ", \"required_reviewers\": []",
            with: "",
            in: RepositoryPolicyFoundation.substitute(
                of: "\"dismissal_restriction\": { \"allowed_actors\": [], \"enabled\": false }, ",
                with: "",
                in: RepositoryPolicyFoundation.substitute(
                    of: "\"allowed_merge_methods\": [\"squash\"], ",
                    with: "",
                    in: String(decoding: canonical, as: UTF8.self)
                )
            )
        )
        // Confirm the substitution actually reproduces the pre-fix shape
        // before asserting on the validator's behavior against it.
        #expect(!unpinned.contains("allowed_merge_methods"))
        #expect(!unpinned.contains("dismissal_restriction"))
        #expect(!unpinned.contains("required_reviewers"))
        let url = [Byte](utf8: unpinned)

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
        }
    }

    // MARK: - Control-plane ruleset contract (swift-institute/.github#200)

    // Positive control: the shipped control-plane fixture is exactly three
    // rules (deletion, non_fast_forward, pull_request), carries no
    // required_status_checks rule at all, and pins the identical
    // pull-request transaction as the package contract.
    @Test
    func protectedMainControlPayloadFixtureDefinesTheControlPlaneTransaction() throws {
        let url = try policy("protected-main-control-ruleset")
        let payload = try Institute.Repository.Policy.Ruleset.protectedMainControlPayload(from: url)
        let object = try #require(try RepositoryPolicyFoundation.jsonObject(with: payload.map { $0.underlying }) as? [String: Any])
        #expect((object["name"] as? String) == "Institute protected main (control)")
        #expect((object["bypass_actors"] as? [Any])?.isEmpty == true)
        #expect((object["enforcement"] as? String) == "active")
        let rules = try #require(object["rules"] as? [[String: Any]])
        #expect(
            Set(rules.compactMap { $0["type"] as? String })
                == ["deletion", "non_fast_forward", "pull_request"]
        )
        #expect(!rules.contains { $0["type"] as? String == "required_status_checks" })
        let review = try #require(
            rules.first(where: { $0["type"] as? String == "pull_request" })?["parameters"]
                as? [String: Any]
        )
        #expect(review["required_approving_review_count"] as? Int == 0)
        #expect(review["require_last_push_approval"] as? Bool == false)
        #expect(review["dismiss_stale_reviews_on_push"] as? Bool == true)
        #expect(review["required_review_thread_resolution"] as? Bool == true)
        #expect(review["allowed_merge_methods"] as? [String] == ["squash"])
        #expect((review["required_reviewers"] as? [Any])?.isEmpty == true)
    }

    // Discriminating negative: a package contract missing its
    // required_status_checks rule (name unchanged) must still be refused —
    // isolates the rule-completeness check from the name/identity check.
    @Test
    func protectedMainPayloadRejectsAPayloadMissingTheRequiredStatusChecksRule() throws {
        let canonical = try policy("protected-main-ruleset")
        var object = try #require(
            try RepositoryPolicyFoundation.jsonObject(with: canonical.map { $0.underlying }) as? [String: Any]
        )
        var rules = try #require(object["rules"] as? [[String: Any]])
        rules.removeAll { $0["type"] as? String == "required_status_checks" }
        object["rules"] = rules
        let url = try scratchFixture(object)

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: url)
        }
    }

    // Discriminating negative: a control contract carrying a smuggled
    // required_status_checks rule (name unchanged) must be refused — the
    // control contract's rule-type set admits exactly three rules.
    @Test
    func protectedMainControlPayloadRejectsASmuggledRequiredStatusChecksRule() throws {
        let canonical = try policy("protected-main-control-ruleset")
        var object = try #require(
            try RepositoryPolicyFoundation.jsonObject(with: canonical.map { $0.underlying }) as? [String: Any]
        )
        var rules = try #require(object["rules"] as? [[String: Any]])
        rules.append([
            "type": "required_status_checks",
            "parameters": [
                "do_not_enforce_on_create": false,
                "required_status_checks": [["context": "ci / ci-ok"]],
                "strict_required_status_checks_policy": true,
            ],
        ])
        object["rules"] = rules
        let url = try scratchFixture(object)

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainControlPayload(from: url)
        }
    }

    // Cross-validation: the control validator must refuse the real package
    // payload (wrong name, and a required_status_checks rule the control
    // rule-type set does not admit).
    @Test
    func protectedMainControlPayloadRejectsTheRealPackagePayload() throws {
        let canonical = try policy("protected-main-ruleset")

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainControlPayload(from: canonical)
        }
    }

    // Cross-validation: the package validator must refuse the real control
    // payload (wrong name, and no required_status_checks rule at all).
    @Test
    func protectedMainPayloadRejectsTheRealControlPayload() throws {
        let canonical = try policy("protected-main-control-ruleset")

        #expect(throws: Institute.Repository.Policy.Ruleset.Error.self) {
            try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: canonical)
        }
    }

    // MARK: - Ruleset sweep convergence (swift-institute/.github#204)

    // Positive: an Institute ruleset that already exists is always
    // re-applied, under either sweep posture — the nightly's scheduled-heal
    // mode heals drift exactly like the explicit-apply mode does.
    @Test
    func decideConvergenceReappliesAnExistingRulesetUnderEitherMode() {
        for mode: Institute.Repository.Policy.Ruleset.SweepMode in [.scheduledHeal, .explicitApply] {
            let decision = Institute.Repository.Policy.Ruleset.decideConvergence(
                rulesetExists: true,
                mode: mode
            )
            #expect(decision.action == .reapply, "\(mode)")
        }
    }

    // Positive: an absent ruleset under the explicit apply-rulesets opt-in
    // still creates — the swift-institute/.github#193 first-application
    // path is unchanged by #204.
    @Test
    func decideConvergenceCreatesAnAbsentRulesetUnderExplicitApply() {
        let decision = Institute.Repository.Policy.Ruleset.decideConvergence(
            rulesetExists: false,
            mode: .explicitApply
        )
        #expect(decision.action == .create)
    }

    // Discriminating negative: an absent ruleset under the nightly's
    // scheduled-heal posture is skipped, never created — first application
    // on a previously unenforced repository stays excluded from the
    // scheduled path (explicit opt-in only).
    @Test
    func decideConvergenceSkipsAnAbsentRulesetUnderScheduledHeal() {
        let decision = Institute.Repository.Policy.Ruleset.decideConvergence(
            rulesetExists: false,
            mode: .scheduledHeal
        )
        #expect(decision.action == .skipAbsentOnSchedule)
        #expect(decision.reason.contains("explicit opt-in only"))
    }

    // EXCISED (host-subject residue; TX-APP2B/2C precedent): five tests
    // asserting against the live swift-institute/.github workflow tree
    // (`ruleset org enumerator excludes forks`,
    // nightlySweepEnablesHealRulesetsAndNotApplyRulesets,
    // rulesetsJobGatesOnEitherOptInAndDelegatesTheConvergenceDecision,
    // rulesetsJobReadsVisibilityLiveAndFailsClosedOnAnUnrecognizedValue,
    // botReviewTransactionSourcesCollectionsFromFiles) were removed here.
    // The originals remain in .github and transfer/rebind at TX-APP2Z.

    // MARK: - Issue-record grammar

    @Test
    func issueRecordParserAcceptsTheCompactTaskProfile() throws {
        let record = try Institute.Repository.Policy.Issue.Parser.record(
            """
            ### Kind

            Task

            ### Owner coordinate

            swift-institute/.github

            ### Status

            Active

            ### Grammar version

            1
            """
        )

        #expect(record.kind == .task)
        #expect(record.owner == "swift-institute/.github")
        #expect(record.status == .active)
        #expect(record.grammarVersion == 1)
    }

    // Positive control: an omitted core field must be reported malformed,
    // not silently accepted as an otherwise clean record.
    @Test
    func issueRecordReconcilerReportsMalformedCore() {
        let report = Institute.Repository.Policy.Issue.reconcile([
            .init(
                coordinate: "swift-institute/.github#173",
                body: """
                    ### Kind

                    Task

                    ### Owner coordinate

                    swift-institute/.github

                    ### Status

                    Active
                    """,
                native: .init(state: .open)
            )
        ])

        #expect(report.map(\.finding) == [.malformed])
    }

    // Positive control: a core-field profile has one value. The parser must
    // not overwrite a malformed first value with a later conforming one.
    @Test
    func issueRecordReconcilerRejectsAdditionalCoreFieldContent() {
        let report = Institute.Repository.Policy.Issue.reconcile([
            .init(
                coordinate: "swift-institute/.github#173",
                body: """
                    ### Kind

                    not Task
                    Task

                    ### Owner coordinate

                    swift-institute/.github

                    ### Status

                    Active

                    ### Grammar version

                    1
                    """,
                native: .init(state: .open)
            )
        ])

        #expect(report.map(\.finding) == [.malformed])
    }

    @Test
    func issueRecordReconcilerSeparatesNativeStateAndUnavailableInputs() throws {
        let active = """
            ### Kind

            Task

            ### Owner coordinate

            swift-institute/.github

            ### Status

            Active

            ### Grammar version

            1
            """
        let decision = try Institute.Repository.Policy.Issue.Decision(
            grammarVersion: 1,
            status: "superseded",
            supersededBy: "https://github.com/swift-institute/.github/issues/174"
        )

        let report = Institute.Repository.Policy.Issue.reconcile([
            .init(coordinate: "z#1", body: nil, native: .init(state: .open)),
            .init(coordinate: "a#1", body: active, native: .init(state: .completed)),
            .init(coordinate: "b#1", body: active, native: .init(state: .open), decision: decision),
            .init(coordinate: "c#1", body: active, native: .init(state: .open, parent: "a#0")),
        ])

        #expect(report.map(\.coordinate) == ["a#1", "b#1", "c#1", "z#1"])
        #expect(report.map(\.finding) == [.stale, .superseded, .conforming, .unavailable])
    }

    @Test
    func issueRecordReconcilerIncludesEveryPage() {
        let report = Institute.Repository.Policy.Issue.reconcile(pages: [
            .init(
                inputs: [.init(coordinate: "b#2", body: nil, native: .init(state: .open))],
                hasNextPage: true
            ),
            .init(
                inputs: [.init(coordinate: "a#1", body: nil, native: .init(state: .open))],
                hasNextPage: false
            ),
        ])

        #expect(report.map(\.coordinate) == ["a#1", "b#2"])
        #expect(report.map(\.finding) == [.unavailable, .unavailable])
    }

    @Test
    func typedLifecycleRecordsRejectInvalidVersionAndDigest() {
        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.CompactionCheckpoint(
                grammarVersion: 2,
                source: "https://github.com/swift-institute/.github/issues/173",
                digest: "0123456789abcdef0123456789abcdef01234567"
            )
        }
        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.TerminalReceipt(
                grammarVersion: 1,
                revision: "not-a-revision",
                verification: "workspace package test"
            )
        }
    }

    @Test
    func `Issue snapshot digest matches known vectors across chunk boundaries`() {
        let vectors = [
            ("", "da39a3ee5e6b4b0d3255bfef95601890afd80709"),
            ("abc", "a9993e364706816aba3e25717850c26c9cd0d89d"),
            (String(repeating: "a", count: 64), "0098ba824b5c16427bd7a1122a5a442a25ec644d"),
            (String(repeating: "a", count: 65), "11655326c708d70319be2610e8a57d9a5b959d3b"),
        ]

        for (body, digest) in vectors {
            let snapshot = Institute.Repository.Policy.Issue.Snapshot(
                coordinate: "swift-institute/.github#183",
                revision: "\"known-vector\"",
                body: body,
                native: .init(state: .open)
            )

            #expect(snapshot.digest == digest)
        }
    }

    @Test
    func activeRecordCompactorRendersOnlyTheCurrentSpecificationAndCheckpoint() throws {
        let body = """
            ### Problem

            Earlier detail remains in the Issue timeline.

            ### Kind

            Task

            ### Owner coordinate

            swift-institute/.github

            ### Status

            Active

            ### Grammar version

            1

            ### Proposed outcome

            Compact this current body without touching history.
            """
        let snapshot = Institute.Repository.Policy.Issue.Snapshot(
            coordinate: "https://github.com/swift-institute/.github/issues/174",
            revision: "\"issue-174-v1\"",
            body: body,
            native: .init(state: .open)
        )
        let expected = try Institute.Repository.Policy.Issue.Guard(
            revision: snapshot.revision,
            digest: snapshot.digest
        )

        let plan = try #require(
            try Institute.Repository.Policy.Issue.Compactor.plan(snapshot: snapshot, guard: expected)
        )

        #expect(
            plan.body == """
                ### Kind

                Task

                ### Owner coordinate

                swift-institute/.github

                ### Status

                Active

                ### Grammar version

                1
                """
        )
        #expect(
            try Institute.Repository.Policy.Issue.Parser.checkpoint(plan.checkpoint).source
                == snapshot.coordinate
        )
        #expect(
            try Institute.Repository.Policy.Issue.Parser.checkpoint(plan.checkpoint).digest == snapshot.digest
        )
        #expect(!plan.body.contains("Earlier detail"))
        #expect(!plan.checkpoint.contains("Earlier detail"))
    }

    // Positive control: a changed entity tag OR a changed body digest must
    // refuse before any body rewrite or checkpoint can be proposed.
    @Test
    func activeRecordCompactorRefusesStaleRevisionAndDigest() throws {
        let body = """
            ### Kind

            Task

            ### Owner coordinate

            swift-institute/.github

            ### Status

            Active

            ### Grammar version

            1

            ### Problem

            Needs compaction.
            """
        let snapshot = Institute.Repository.Policy.Issue.Snapshot(
            coordinate: "https://github.com/swift-institute/.github/issues/174",
            revision: "\"current\"",
            body: body,
            native: .init(state: .open)
        )
        let staleRevision = try Institute.Repository.Policy.Issue.Guard(
            revision: "\"stale\"",
            digest: snapshot.digest
        )
        let staleDigest = try Institute.Repository.Policy.Issue.Guard(
            revision: snapshot.revision,
            digest: "a9993e364706816aba3e25717850c26c9cd0d89d"
        )

        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.Compactor.plan(snapshot: snapshot, guard: staleRevision)
        }
        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.Compactor.plan(snapshot: snapshot, guard: staleDigest)
        }
    }

    @Test
    func activeRecordCompactorRefusesTerminalAndInactiveRecords() throws {
        let body = """
            ### Kind

            Task

            ### Owner coordinate

            swift-institute/.github

            ### Status

            Blocked

            ### Grammar version

            1
            """
        let snapshot = Institute.Repository.Policy.Issue.Snapshot(
            coordinate: "https://github.com/swift-institute/.github/issues/174",
            revision: "\"current\"",
            body: body,
            native: .init(state: .open)
        )
        let expected = try Institute.Repository.Policy.Issue.Guard(
            revision: snapshot.revision,
            digest: snapshot.digest
        )

        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.Compactor.plan(snapshot: snapshot, guard: expected)
        }
        let terminal = Institute.Repository.Policy.Issue.Snapshot(
            coordinate: snapshot.coordinate,
            revision: snapshot.revision,
            body: snapshot.body,
            native: .init(state: .completed)
        )
        #expect(throws: Institute.Repository.Policy.Issue.Error.self) {
            try Institute.Repository.Policy.Issue.Compactor.plan(snapshot: terminal, guard: expected)
        }
    }

    private func render(_ decision: Institute.Repository.Policy.Decision) -> String {
        switch decision {
        case .excluded(let reason): reason.rawValue
        case .converged: "converged"
        case .enable: "enable"
        }
    }

    private struct Fixture: Decodable {
        let name: String
        let repository: Institute.Repository.Policy.Repository
        let manifestKind: String?
        let pvr: String?
        let decision: String

        enum CodingKeys: String, CodingKey {
            case name
            case repository
            case manifestKind = "manifest_kind"
            case pvr
            case decision
        }
    }
}
