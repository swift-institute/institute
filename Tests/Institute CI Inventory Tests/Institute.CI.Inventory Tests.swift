public import Institute_Model
import Institute_CI_Model
import Institute_CI_Workflow
import GitHub_Standard
import Testing

@testable import Institute_CI_Inventory

/// The vendor-neutral contract type, aliased at file scope so the
/// reference cannot rebind to the `Institute.CI`
/// nest inside the suites below.
private typealias ContractRequirement = Institute.CI.Requirement

/// Owner-local inventory behavior over the terminal one-hop topology.
/// Live host correspondence is checked at the exact `.github` candidate
/// head; this package does not vendor a second copy of that workflow.
@Suite
struct CIInventoryTests {
    static let terminalTopology = """
        name: CI
        on:
          workflow_call:
        jobs:
          plan:
            if: ${{ !github.event.repository.private }}
            runs-on: ubuntu-latest
            steps:
              - name: Classify tier
                run: institute-continuous-integration package plan
          source:
            if: ${{ !github.event.repository.private }}
            needs: plan
            runs-on: xcode-27
          linux-release:
            if: ${{ !github.event.repository.private }}
            needs: plan
            runs-on: ubuntu-latest
          macos-release:
            if: ${{ !github.event.repository.private }}
            needs: plan
            runs-on: macos-latest
          windows-release:
            if: ${{ !github.event.repository.private }}
            needs: plan
            runs-on: windows-latest
          linux-6-4:
            if: ${{ !github.event.repository.private }}
            needs: plan
            continue-on-error: true
            strategy:
              matrix:
                swift: ["6.4"]
            runs-on: ubuntu-latest
          advisory-summary:
            if: ${{ !github.event.repository.private }}
            needs: [plan, linux-6-4]
            continue-on-error: true
            runs-on: ubuntu-latest
          ci-ok:
            if: ${{ !github.event.repository.private }}
            needs: [plan, source, linux-release, macos-release, windows-release]
            runs-on: ubuntu-latest
        """

    static func sample() throws -> Institute.CI.Inventory.Document {
        try Institute.CI.Inventory.Document(
            universalWorkflow: terminalTopology
        )
    }

    @Suite
    struct Topology {
        @Test func `the inventory describes one hop, not three`() throws {
            #expect(Institute.CI.Inventory.Document.callerHops == 1)
            #expect(Institute.CI.Inventory.Document.schemaVersion == 2)
        }

        @Test func `the verdict resolves to the one required check context`() throws {
            #expect(
                Institute.CI.Inventory.Aggregate.checkContext
                    == "ci / matrix / ci-ok"
            )
            #expect(
                Institute.CI.Inventory.Aggregate.checkContext
                    == ContractRequirement.checkContext
            )
        }

        @Test func `ci-ok is the only authored aggregate that gates`() throws {
            let universal = try CIInventoryTests.sample().universal
            let aggregates = universal.jobs.filter { $0.posture == .aggregate }
            #expect(Set(aggregates.map(\.id)) == ["ci-ok", "advisory-summary"])
            #expect(!universal.aggregate.gatingJobs.isEmpty)
            #expect(universal.aggregate.gatingJobs.allSatisfy { $0 != "advisory-summary" })
        }

        @Test func `the only inner aggregate is a native matrix job and gates nothing`() throws {
            let universal = try CIInventoryTests.sample().universal
            let inner = Set(universal.aggregate.innerMatrixJobs)
            #expect(!inner.isEmpty)
            #expect(inner.isDisjoint(with: Set(universal.aggregate.gatingJobs)))
        }
    }

    @Suite
    struct Derivation {
        @Test func `every job's posture is exactly one of the five`() throws {
            let universal = try CIInventoryTests.sample().universal
            let gating = Set(universal.aggregate.gatingJobs)
            let advisory = Set(universal.aggregate.advisoryJobs)
            #expect(gating.isDisjoint(with: advisory))
            for job in universal.jobs {
                switch job.posture {
                case .plan: #expect(job.id == "plan")
                case .aggregate: #expect(["ci-ok", "advisory-summary"].contains(job.id))
                case .gating: #expect(gating.contains(job.id))
                case .advisory: #expect(advisory.contains(job.id))

                case .eventGated:
                    #expect(!gating.contains(job.id))
                    #expect(!advisory.contains(job.id))
                }
            }
            #expect(universal.jobCount == universal.jobs.count)
        }

        @Test func `an aggregate sits at a strictly higher wave than everything it needs`() throws {
            let universal = try CIInventoryTests.sample().universal
            let ciOk = try #require(universal.job("ci-ok"))
            for id in universal.aggregate.gatingJobs {
                let leg = try #require(universal.job(id))
                #expect(leg.wave < ciOk.wave)
            }
            #expect(try #require(universal.job("plan")).wave == 0)
        }

        @Test func `no cache step ever caches the build directory`() throws {
            let universal = try CIInventoryTests.sample().universal
            for step in universal.cacheSteps {
                let path =
                    step.path.map(Institute.CI.Workflow.YAML.Canonical.json) ?? ""
                #expect(!path.contains(".build"))
            }
        }

        @Test func `the plan delegates its leg vocabulary to its Swift owner`() throws {
            let plan = try CIInventoryTests.sample().universal.plan
            // The retired inventory re-extracted this from a `LEGS="…"`
            // shell literal that no longer exists, and had been
            // recording an EMPTY vocabulary as the shipped truth.
            #expect(plan.delegatesToInstituteCI)
            #expect(!Institute.CI.Inventory.Plan.fullTierLegs.isEmpty)
        }

        @Test func `every full-tier leg names a job the universal actually declares`() throws {
            let universal = try CIInventoryTests.sample().universal
            let declared = Set(universal.jobs.map(\.id))
            for leg in Institute.CI.Inventory.Plan.fullTierLegs {
                #expect(declared.contains(leg), "full-tier leg '\(leg)' is not a declared job")
            }
        }

        @Test func `every gating job carries the private-visibility guard`() throws {
            // A guarded gating job reports NO signal on a private
            // repository. That is a deliberate property of the shipped
            // verdict, and it is worth failing on if it ever becomes
            // partial: half-guarded gating is a verdict that means
            // different things in the two visibilities.
            let universal = try CIInventoryTests.sample().universal
            for id in universal.aggregate.gatingJobs {
                #expect(try #require(universal.job(id)).privateGuarded)
            }
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `a workflow with no jobs is refused, not inventoried as empty`() {
            #expect(throws: Institute.CI.Inventory.Error.noJobs) {
                try Institute.CI.Inventory.Document(
                    universalWorkflow: "on:\n  push:\n"
                )
            }
        }

        @Test func `a workflow with no ci-ok is refused by name`() {
            #expect(throws: Institute.CI.Inventory.Error.missingJob("ci-ok")) {
                try Institute.CI.Inventory.Document(
                    universalWorkflow: "jobs:\n  plan:\n    runs-on: ubuntu-latest\n"
                )
            }
        }

        @Test func `a workflow with no plan is refused by name`() {
            #expect(throws: Institute.CI.Inventory.Error.missingJob("plan")) {
                try Institute.CI.Inventory.Document(
                    universalWorkflow: "jobs:\n  ci-ok:\n    runs-on: ubuntu-latest\n"
                )
            }
        }

        @Test func `a bare needs scalar is the same DAG as a one-element list`() {
            var cache: [String: Int] = [:]
            let waves = ["a": [], "b": ["a"], "c": ["a", "b"]]
            #expect(
                Institute.CI.Inventory.Universal.wave(
                    of: "a",
                    needs: waves,
                    cache: &cache
                ) == 0
            )
            #expect(
                Institute.CI.Inventory.Universal.wave(
                    of: "c",
                    needs: waves,
                    cache: &cache
                ) == 2
            )
        }

        @Test func `a needs entry naming an undeclared job contributes no wave`() {
            var cache: [String: Int] = [:]
            let waves = ["a": ["ghost"]]
            #expect(
                Institute.CI.Inventory.Universal.wave(
                    of: "a",
                    needs: waves,
                    cache: &cache
                ) == 0
            )
        }
    }
}
