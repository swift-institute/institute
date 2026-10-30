import Institute_Model
import Testing

@testable import Institute_Version

extension Institute.Version.Sweep {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Version.Sweep.Test {
    static let a = Fixture.commit("a")
    static let b = Fixture.commit("b")
    static let c = Fixture.commit("c")

    static func sweep(
        _ fixture: Fixture,
        mode: Institute.Version.Sweep.Mode = .continuous,
        dryRun: Swift.Bool = false
    ) -> [Institute.Version.Report] {
        Institute.Version.Sweep(mode: mode, dryRun: dryRun, client: fixture.client).run([Fixture.organization])
    }

    static func outcomes(_ reports: [Institute.Version.Report]) -> [Institute.Version.Outcome] {
        reports.map(\.outcome)
    }

    static func tag(_ name: Swift.String, _ commit: Swift.String) -> Institute.Version.Tag {
        .init(name: name, commit: commit)
    }
}

extension Institute.Version.Sweep.Test.Unit {
    typealias T = Institute.Version.Sweep.Test

    @Test func `the first passing head of a repository gets 0.0.100`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add("swift-one", head: T.a)
        #expect(T.outcomes(T.sweep(fixture)) == [.tagged(T.tag("0.0.100", T.a))])
        #expect(fixture.creations.map(\.1) == [T.tag("0.0.100", T.a)])
    }

    @Test func `each later passing push gets the next ordinal`() {
        let fixture = Fixture(.init(gates: [T.b: .passed]))
        fixture.add("swift-one", head: T.b, tags: [T.tag("0.0.100", T.a)])
        #expect(T.outcomes(T.sweep(fixture)) == [.tagged(T.tag("0.0.101", T.b))])
    }

    @Test func `a second sweep of the same head writes nothing`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add("swift-one", head: T.a)
        _ = T.sweep(fixture)
        #expect(T.outcomes(T.sweep(fixture)) == [.current(T.tag("0.0.100", T.a))])
        #expect(fixture.creations.count == 1)
    }

    @Test func `tags off the line neither count nor block`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add(
            "swift-one",
            head: T.a,
            tags: [T.tag("ci-binaries", T.b), T.tag("0.1.0", T.b), T.tag("0.0.4", T.b)]
        )
        #expect(T.outcomes(T.sweep(fixture)) == [.tagged(T.tag("0.0.100", T.a))])
    }

    @Test func `archived, private and branchless repositories are skipped`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add("swift-archived", head: T.a, archived: true)
        fixture.add("swift-private", head: T.a, private: true)
        fixture.add("swift-unbranched", head: nil)
        #expect(T.outcomes(T.sweep(fixture)) == [.skipped(.archived), .skipped(.private), .skipped(.unbranched)])
        #expect(fixture.creations.isEmpty)
    }

    @Test func `a head whose CI has not passed is not tagged`() {
        let fixture = Fixture(.init(gates: [T.a: .pending, T.b: .failed("failure")]))
        fixture.add("swift-one", head: T.a)
        fixture.add("swift-two", head: T.b)
        fixture.add("swift-three", head: T.c)
        #expect(
            // By name: swift-one, swift-three, swift-two.
            T.outcomes(T.sweep(fixture)) == [.waiting(.pending), .waiting(.absent), .held("failure")]
        )
        #expect(fixture.creations.isEmpty)
    }

    @Test func `a dry run reports exactly what it would tag and writes nothing`() {
        let fixture = Fixture(.init(gates: [T.b: .passed]))
        fixture.add("swift-one", head: T.b, tags: [T.tag("0.0.100", T.a)])
        let reports = T.sweep(fixture, dryRun: true)
        #expect(T.outcomes(reports) == [.planned(T.tag("0.0.101", T.b))])
        #expect(reports.map(\.head) == [T.b])
        #expect(fixture.creations.isEmpty)
    }

    @Test func `backfill tags only repositories not yet on the line`() {
        let fixture = Fixture(.init(gates: [T.a: .passed, T.b: .passed]))
        fixture.add("swift-one", head: T.a)
        fixture.add("swift-two", head: T.b, tags: [T.tag("0.0.100", T.c)])
        #expect(
            T.outcomes(T.sweep(fixture, mode: .backfill)) == [
                .tagged(T.tag("0.0.100", T.a)), .versioned(T.tag("0.0.100", T.c)),
            ]
        )
    }

    @Test func `backfill run twice tags once`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add("swift-one", head: T.a)
        _ = T.sweep(fixture, mode: .backfill)
        #expect(T.outcomes(T.sweep(fixture, mode: .backfill)) == [.current(T.tag("0.0.100", T.a))])
        #expect(fixture.creations.count == 1)
    }
}

extension Institute.Version.Sweep.Test.`Edge Case` {
    typealias T = Institute.Version.Sweep.Test

    @Test(arguments: [Institute.Version.Relation.behind, .diverged])
    func `a head that does not descend from the latest tag is refused`(_ relation: Institute.Version.Relation) {
        let fixture = Fixture(.init(gates: [T.b: .passed], relations: ["\(T.a)...\(T.b)": relation]))
        fixture.add("swift-one", head: T.b, tags: [T.tag("0.0.100", T.a)])
        let reports = T.sweep(fixture)
        #expect(T.outcomes(reports) == [.refused(latest: T.tag("0.0.100", T.a), relation: relation)])
        #expect(reports[0].outcome.blocking)
        #expect(fixture.creations.isEmpty)
    }

    @Test func `the head is compared with the highest ordinal, not the newest name`() {
        let fixture = Fixture(
            .init(gates: [T.c: .passed], relations: ["\(T.a)...\(T.c)": .diverged])
        )
        fixture.add("swift-one", head: T.c, tags: [T.tag("0.0.101", T.b), T.tag("0.0.100", T.a)])
        #expect(T.outcomes(T.sweep(fixture)) == [.tagged(T.tag("0.0.102", T.c))])
    }

    @Test func `a head that already carries a line tag is current even when CI is red`() {
        let fixture = Fixture(.init(gates: [T.a: .failed("failure")]))
        fixture.add("swift-one", head: T.a, tags: [T.tag("0.0.100", T.a)])
        #expect(T.outcomes(T.sweep(fixture)) == [.current(T.tag("0.0.100", T.a))])
    }

    @Test func `losing the race to a writer that tagged the same commit is success`() {
        let fixture = Fixture(.init(gates: [T.a: .passed], racer: T.a))
        fixture.add("swift-one", head: T.a)
        #expect(T.outcomes(T.sweep(fixture)) == [.current(T.tag("0.0.100", T.a))])
        #expect(fixture.creations.isEmpty)
    }

    @Test func `losing the race to a writer that tagged another commit leaves both alone`() {
        let fixture = Fixture(.init(gates: [T.b: .passed], racer: T.a))
        fixture.add("swift-one", head: T.b)
        let reports = T.sweep(fixture)
        #expect(T.outcomes(reports) == [.contended(T.tag("0.0.100", T.b), existing: T.a)])
        #expect(!reports[0].outcome.blocking)
        #expect(fixture.creations.isEmpty)
        // The next sweep orders the head after the tag the other writer made.
        #expect(T.outcomes(T.sweep(fixture)) == [.tagged(T.tag("0.0.101", T.b))])
    }

    @Test func `one failing repository does not stop the others`() {
        let fixture = Fixture(.init(gates: [T.a: .passed], broken: [Fixture.repository("swift-broken")]))
        fixture.add("swift-broken", head: T.a)
        fixture.add("swift-one", head: T.a)
        let outcomes = T.outcomes(T.sweep(fixture))
        #expect(outcomes.count == 2)
        #expect(outcomes[0].blocking)
        #expect(outcomes[1] == .tagged(T.tag("0.0.100", T.a)))
    }

    @Test func `naming repositories sweeps only those`() {
        let fixture = Fixture(.init(gates: [T.a: .passed]))
        fixture.add("swift-one", head: T.a)
        fixture.add("swift-two", head: T.a)
        let reports = Institute.Version.Sweep(mode: .continuous, dryRun: true, client: fixture.client)
            .run([Fixture.organization], repositories: [Fixture.repository("swift-two")])
        #expect(reports.map(\.repository.name) == ["swift-two"])
    }
}
