import Testing

@testable import Institute_Doctor
@testable import Institute_Model

// MARK: - Source preparation assertion

extension Institute.Doctor.Test.Unit {
    @Test
    func `an unprepared checkout is a warning naming the prepare command`() {
        let outcome = Institute.Doctor.preparation.run(
            population: [.prepared(false)],
            inventory: 2
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("institute source prepare") })
    }

    @Test
    func `a current preparation passes`() {
        let outcome = Institute.Doctor.preparation.run(
            population: [.prepared(true), .current(stale: nil)],
            inventory: 2
        )

        #expect(outcome.result == .ok(population: 2))
    }

    @Test
    func `a stale preparation is a warning naming the staleness reason`() {
        let outcome = Institute.Doctor.preparation.run(
            population: [.prepared(true), .current(stale: "stale-tool: .source")],
            inventory: 2
        )

        #expect(outcome.result == .finding(severity: .warning, population: 2))
        #expect(outcome.findings.contains { $0.message.contains("stale-tool") })
    }
}
