import Byte
public import Institute_Model
import Institute_Repository_Policy
import Testing

@testable import Institute_Repository_Application

/// Shape policy 5 measured the way git will measure it.
///
/// Reading the allowlist patterns and reasoning about them is how the
/// premise of the shim wave came to be wrong in the first place: policy 4
/// looked like it admitted `Sources/**` when its only re-inclusions were
/// `*.swift` and `*.docc/**`, so every C shim header a `* Shims` target
/// needs was silently untracked. These probes therefore materialise a
/// throwaway repository, hand git the embedded payload as its `.gitignore`,
/// and let `git add` decide — directory pruning and all — rather than
/// asserting over pattern text.
@Suite
struct `Repository Policy Uniformity Wave Payload Tests` {
    /// Paths a `* Shims` target needs, which policy 4 denied and policy 5
    /// must admit.
    private static let admitted = [
        "Sources/ARM Shims/shim.c",
        "Sources/CPU Shims/include/atomic.h",
        "Sources/Foo Shims/include/module.modulemap",
    ]

    /// Near misses that must stay denied. `CIEEE754` is not a `* Shims`
    /// directory despite starting with `C`; `Shims` alone has no space-
    /// separated prefix; `README.md` is not a shim source; `.cpp` is not
    /// one of the three admitted extensions.
    private static let denied = [
        "Sources/CIEEE754/x.c",
        "Sources/Foo Shims/README.md",
        "Sources/Shims/x.h",
        "Sources/Type Metadata Shims/T.cpp",
    ]

    @Test
    func policyFiveAdmitsShimSourcesAndStillDeniesTheirNearMisses() throws {
        let probes = Self.admitted + Self.denied
        let repository = GitProbeRepository()
        try repository.initialize()
        try repository.write(
            Institute.Repository.Policy.Uniformity.Wave.Payload.canonical(),
            to: ".gitignore"
        )
        for probe in probes {
            try repository.write([Byte](utf8: "probe\n"), to: probe)
        }
        // A Swift source under an ordinary target is the positive control:
        // if it is missing from the tracked set the harness, not the
        // policy, is what failed.
        try repository.write([Byte](utf8: "// probe\n"), to: "Sources/Foo/Foo.swift")

        try repository.run(["add", "-A"])
        let tracked = Set(try repository.trackedPaths())

        #expect(tracked.contains("Sources/Foo/Foo.swift"))
        #expect(tracked.contains(".gitignore"))
        for path in Self.admitted {
            #expect(tracked.contains(path), "policy 5 must admit \(path)")
        }
        for path in Self.denied {
            #expect(!tracked.contains(path), "policy 5 must deny \(path)")
        }
    }
}
