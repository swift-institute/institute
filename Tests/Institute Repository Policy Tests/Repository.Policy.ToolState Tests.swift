public import Institute_Model
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy ToolState Tests` {
    @Test
    func `a tracked file under swiftpm at any depth is a finding, and a name that only contains it is not`() {
        let tracked = [
            "Package.swift",
            ".swiftpm/xcode/xcshareddata/xcschemes/swift-sqlite-Package.xcscheme",
            "Sources/Core/Value.swift",
            "Tests/Fixture/.swiftpm/configuration/mirrors.json",
            "Sources/Core/swiftpm.swift",
            ".swiftpm-notes/readme.txt",
        ]
        #expect(
            Institute.Repository.Policy.ToolState.findings(in: tracked) == [
                ".swiftpm/xcode/xcshareddata/xcschemes/swift-sqlite-Package.xcscheme",
                "Tests/Fixture/.swiftpm/configuration/mirrors.json",
            ]
        )
    }
}
