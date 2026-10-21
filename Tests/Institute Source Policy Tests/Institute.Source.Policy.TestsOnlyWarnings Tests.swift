import Institute_Source_Policy
import Testing

@Suite
struct `Institute source policy tests-only warnings` {
    private let policy = Institute.Source.Policy.current

    @Test
    func `force-try, force-unwrap and early-exit findings are warnings under Tests`() {
        for identifier in ["force_try", "NeverUseForceTry", "NeverForceUnwrap", "UseEarlyExits"] {
            #expect(policy.reportsAsWarning(identifier: identifier, path: "/work/repo/Tests/A Tests/File.swift", root: "/work/repo"))
            #expect(policy.reportsAsWarning(identifier: identifier, path: "Tests/A Tests/File.swift", root: "/work/repo"))
            #expect(!policy.reportsAsWarning(identifier: identifier, path: "/work/repo/Sources/A/File.swift", root: "/work/repo"))
            #expect(!policy.reportsAsWarning(identifier: identifier, path: "/work/repo/Sources/Tests/File.swift", root: "/work/repo"))
        }
    }

    @Test
    func `other rules stay errors under Tests`() {
        #expect(!policy.reportsAsWarning(identifier: "typed_throws_required", path: "/work/repo/Tests/File.swift", root: "/work/repo"))
    }
}
