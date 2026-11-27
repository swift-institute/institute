public import Institute_Model
import Institute_Repository_Policy
import JSON
import Testing

@Suite
struct `Repository Policy Automation Tests` {
    @Test
    func csvQuotingMatchesMinimalDialect() {
        #expect(Institute.Repository.Policy.Automation.quoted("plain") == "plain")
        #expect(Institute.Repository.Policy.Automation.quoted("a,b") == "\"a,b\"")
        #expect(Institute.Repository.Policy.Automation.quoted("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(Institute.Repository.Policy.Automation.quoted("line\nbreak") == "\"line\nbreak\"")
    }

    @Test
    func generatorScansWorkflowCoordinates() throws {
        let root = AutomationFoundation.temporaryRoot(name: AutomationFoundation.uuidString())
        defer { AutomationFoundation.removeItem(atPath: root) }
        let workflows = root + "/.github/workflows"
        try AutomationFoundation.createDirectory(atPath: workflows)
        let yaml = """
            on: push
            jobs:
              demo:
                runs-on: ${{ matrix.os }}
                steps:
                  - uses: actions/checkout@0000000000000000000000000000000000000000
                  - name: block
                    run: |
                      python3 script.py
                      echo done
                  - name: inline
                    run: gh api /rate_limit
            """
        try AutomationFoundation.write(yaml, toPath: workflows + "/demo.yml")
        let census = try Institute.Repository.Policy.Automation.Generator(
            repos: [
                .init(name: "fixture/repo", root: root, headSha: String(repeating: "a", count: 40))
            ]
        ).run()
        func rows(_ kind: Institute.Repository.Policy.Automation.Kind) -> [Institute.Repository.Policy.Automation.Row] {
            census.rows.filter { $0.coordinateKind == kind && $0.repository == "fixture/repo" }
        }
        #expect(rows(.file).count == 1)
        #expect(rows(.expression).count == 1)
        #expect(rows(.usesEdge).count == 1)
        #expect(rows(.usesEdge).first?.notes.hasPrefix("actions/checkout@") == true)
        #expect(rows(.runBlock).count == 2)
        // `python3` and `gh` count; `echo` is a skip-listed builtin.
        #expect(rows(.commandReference).map(\.notes).sorted() == ["gh", "python3"])
        // Frozen family and sentinel rows always present.
        #expect(census.rows.contains { $0.coordinateId == "family:leaf-callers" })
        #expect(census.rows.filter { $0.measurement == "UNMEASURED" }.count == 5)
    }

    @Test
    func capabilityRecordsAreFrozen() throws {
        #expect(Institute.Repository.Policy.Capability.records.count == 12)
        #expect(Institute.Repository.Policy.Capability.records.first?.id == "D-01")
        let rendered = Institute.Repository.Policy.Capability.records
            .jsonString(pretty: true, sortKeys: true)
        let decoded = try [Institute.Repository.Policy.Capability](jsonString: rendered)
        #expect(decoded == Institute.Repository.Policy.Capability.records)
    }
}
