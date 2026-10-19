import Byte
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Testing

/// `Parse` is defined as `Render`'s inverse, so the test is the identity
/// that definition asserts — over the seven real callers, not over
/// synthetic text a wrong parser and a wrong expectation could agree on.
///
/// EXCISED (host-subject residue; TX-APP2B/2C precedent): five tests that
/// read `.github/scripts/tests/fixtures/callers/*.yml` in place —
/// roundTripsEveryRealCallerThroughTheCurrentForm,
/// roundTripsEveryRealCallerThroughTheDirectForm,
/// renderingIsAFixpointUnderParsing, ignoresCommentsInsideBlocks, and
/// recoversTheLayerFromTheCalleeNotTheOwnerOrganization — along with the
/// `callers` corpus table and the `text(_:)` helper they alone used, were
/// removed here. The corpus is data: byte-for-byte snapshots of live
/// `ci.yml` files that the source deliberately never copies (copying would
/// make a second spelling that drifts), so the fixtures and these tests
/// stay in .github and transfer/rebind at TX-APP2Z.
@Suite
struct `Repository Policy Caller Parse Tests` {
    /// The legacy `docs:` job's overrides are recovered, not dropped.
    /// Three of the seven carry a real `platform-support`; this asserts
    /// the docs-side mapping with a caller built for it, since no fixture
    /// exercises a `docs:` `with:` block.
    @Test
    func recoversLegacyDocsOverridesOntoTerminalInputs() throws {
        let text = """
            name: CI

            on:
              push:
                branches:
                  - main

            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@main
                with:
                  platform-support: apple,linux
                secrets: inherit

              docs:
                uses: swift-standards/.github/.github/workflows/swift-docs.yml@main
                with:
                  umbrella-module: Demo
                  exclude-modules: Internal
                secrets: inherit
            """
        let spec = try Institute.Repository.Policy.Caller.Parse.caller(
            text,
            repository: "swift-standards/swift-demo-standard"
        )
        #expect(
            spec.inputs.map(\.key) == [
                "platform-support", "docs-umbrella-module", "docs-exclude-modules",
            ]
        )
        #expect(spec.inputs.first { $0.key == "docs-umbrella-module" }?.value == "Demo")
    }

    // MARK: - Failing closed
    //
    // Every refusal `parse_existing_caller` named, asserted as a refusal.
    // A parser that silently accepted these would let a regeneration
    // sweep erase a real customization, which is the failure mode the
    // typed error exists to prevent.

    @Test
    func refusesInlineSteps() throws {
        let text = """
            jobs:
              ci:
                runs-on: ubuntu-latest
                steps:
                  - uses: actions/checkout@v6
            """
        #expect(
            throws: Institute.Repository.Policy.Caller.Error.unknownCustomization(
                "`ci` job carries inline steps/runs-on, not a thin caller"
            )
        ) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    @Test
    func refusesAnUnapprovedInput() throws {
        let text = """
            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@main
                with:
                  bespoke-knob: yes
            """
        #expect(
            throws: Institute.Repository.Policy.Caller.Error.unknownCustomization(
                "unapproved with: key bespoke-knob"
            )
        ) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    @Test
    func refusesAnUnexpectedJob() throws {
        let text = """
            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@main
                secrets: inherit

              publish:
                uses: swift-standards/.github/.github/workflows/swift-publish.yml@main
            """
        #expect(throws: Institute.Repository.Policy.Caller.Error.self) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    @Test
    func refusesACrossWrapperDocsRoute() throws {
        let text = """
            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@main
                secrets: inherit

              docs:
                uses: swift-primitives/.github/.github/workflows/swift-docs.yml@main
                secrets: inherit
            """
        #expect(throws: Institute.Repository.Policy.Caller.Error.self) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    @Test
    func refusesAnUnknownWrapperOrganization() throws {
        let text = """
            jobs:
              ci:
                uses: some-other-org/.github/.github/workflows/swift-ci.yml@main
                secrets: inherit
            """
        #expect(throws: Institute.Repository.Policy.Caller.Error.self) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    /// A tag pin is not a customization this type may normalise away —
    /// the whole caller must fail the canonical-shape check rather than
    /// be silently regenerated at `@main`.
    @Test
    func refusesANonMainPin() throws {
        let text = """
            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@v1
                secrets: inherit
            """
        #expect(throws: Institute.Repository.Policy.Caller.Error.self) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

    /// `integrated-docs` is generator-owned. TX10 deleted it, so `true`
    /// is tolerated on an existing caller and anything else refuses.
    @Test
    func refusesANonTrueIntegratedDocs() throws {
        let text = """
            jobs:
              ci:
                uses: swift-standards/.github/.github/workflows/swift-ci.yml@main
                with:
                  integrated-docs: false
                secrets: inherit
            """
        #expect(
            throws: Institute.Repository.Policy.Caller.Error.unknownCustomization(
                "integrated-docs is present but not true"
            )
        ) {
            try Institute.Repository.Policy.Caller.Parse.caller(text, repository: "swift-iso/swift-x")
        }
    }

}
