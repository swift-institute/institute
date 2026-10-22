import Testing

@testable import Institute_Doctor
@testable import Institute_Model

extension Institute.Doctor.Test.Unit {
    @Test
    func `a workspace with a differently named shared scheme is an error`() {
        let outcome = Institute.Doctor.workspace.run(
            population: [
                .init(
                    repository: "example",
                    name: "example.xcworkspace",
                    schemes: ["Graph"]
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(outcome.findings[0].message.contains("example.xcworkspace"))
        #expect(outcome.findings[0].message.contains("Graph"))
    }

    @Test
    func `a workspace with its one namesake shared scheme passes`() {
        let outcome = Institute.Doctor.workspace.run(
            population: [
                .init(
                    repository: "example",
                    name: "example.xcworkspace",
                    schemes: ["example.xcworkspace"]
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
        #expect(outcome.findings.isEmpty)
    }
}
