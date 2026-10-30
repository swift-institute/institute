import Byte
public import Institute_Model
import Institute_Command
import Institute_Repository_Policy
import Package_Manager
import Testing

@Suite
struct `Repository Policy BranchPin Tests` {
    @Test
    func `the lint bundle follows the owner's organization`() {
        #expect(Institute.Repository.Coordinate("swift-atoms/swift-bool")?.organization.lintBundle == "primitives")
        #expect(Institute.Repository.Coordinate("swift-molecules/swift-pool")?.organization.lintBundle == "primitives")
        #expect(Institute.Repository.Coordinate("swift-ietf/swift-rfc-3986")?.organization.lintBundle == "standards")
        #expect(Institute.Repository.Coordinate("swift-compositions/swift-kernel")?.organization.lintBundle == "institute")
        #expect(Institute.Repository.Coordinate("swift-institute/institute")?.organization.lintBundle == "institute")
        #expect(Institute.Repository.Coordinate("apple/swift-syntax") == nil)
        #expect(Institute.Repository.Coordinate("swift-atoms") == nil)
        #expect(Institute.Organization.lintBundle(forRepository: "swift-ietf/swift-rfc-3986") == "standards")
        #expect(Institute.Organization.lintBundle(forRepository: "coenttb/kees") == "institute")
    }

    @Test
    func `repository deviations come from its metadata`() {
        let deviation = Institute.Repository.Policy.Deviation(
            metadata: """
                description: "A kernel"
                platforms: apple,linux  # no Windows API
                embedded-target: 'Kernel'
                settings:
                  platforms: ignored
                """
        )
        #expect(deviation == .init(platforms: "apple,linux", embeddedTarget: "Kernel"))
        #expect(Institute.Repository.Policy.Deviation(metadata: "description: x\n") == .init())
        #expect(Institute.Repository.Policy.Deviation.read(root: "/nonexistent") == .init())
    }

    @Test
    func `only non-main Institute branches refuse`() {
        let dependencies: [Package.Manifest.Dependency.SourceControl] = [
            .init(
                url: "https://github.com/swift-foundations/swift-alpha.git",
                branch: "feature/x",
                document: "Package.swift"
            ),
            .init(
                url: "https://github.com/swift-foundations/swift-beta.git",
                branch: "main",
                document: "Package.swift"
            ),
            .init(
                url: "https://github.com/elsewhere/swift-gamma.git",
                branch: "feature/x",
                document: "Package.swift"
            ),
        ]

        let findings = Institute.Repository.Policy.BranchPin.findings(
            in: dependencies,
            organizations: ["swift-foundations"]
        )

        #expect(
            findings == [
                .init(
                    document: "Package.swift",
                    url: "https://github.com/swift-foundations/swift-alpha.git",
                    branch: "feature/x"
                )
            ]
        )
    }
}
