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
}
