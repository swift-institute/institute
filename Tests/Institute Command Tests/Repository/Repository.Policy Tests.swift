public import Institute_Model
import Institute_Command
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
