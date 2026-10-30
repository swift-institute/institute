import Byte
public import Institute_Model
import Institute_Command
import Institute_Repository_Policy
import Package_Manager
import Testing

@Suite
struct `Repository Policy BranchPin Tests` {
    @Test
    func `fleet policy decodes active organizations`() throws {
        let path = try #require(
            BranchPinFoundation.resourcePath(forResource: "fleet-minimal", withExtension: "json")
        )
        let fleet = try Institute.Repository.Policy.Fleet.read(at: path)

        #expect(fleet.schemaVersion == 1)
        #expect(fleet.activeOrganizationNames == ["swift-institute"])
        #expect(fleet.repositories == nil)
    }

    @Test
    func `fleet policy resolves layer defaults and repository exceptions`() throws {
        let path = try BranchPinFoundation.writeTemporaryFleetPolicy(
            """
            {
              "schemaVersion": 1,
              "organizations": [
                {"name":"swift-atoms","layer":"L1","status":"active"},
                {"name":"swift-standards","layer":"L3","status":"active"},
                {"name":"swift-compositions","layer":"L4","status":"active"}
              ],
              "repositories": [
                {
                  "name":"swift-compositions/swift-kernel",
                  "platforms":"windows",
                  "embeddedTarget":"Kernel"
                }
              ]
            }
            """
        )

        let fleet = try Institute.Repository.Policy.Fleet.read(at: path)
        #expect(
            try fleet.configuration(for: "swift-atoms/swift-bool")
                == .init(lintBundle: "primitives", platforms: "", embeddedTarget: "")
        )
        #expect(
            try fleet.configuration(for: "swift-standards/swift-css-standard")
                == .init(lintBundle: "standards", platforms: "", embeddedTarget: "")
        )
        #expect(
            try fleet.configuration(for: "swift-compositions/swift-kernel")
                == .init(
                    lintBundle: "institute",
                    platforms: "windows",
                    embeddedTarget: "Kernel"
                )
        )
    }

    @Test
    func `fleet policy refuses malformed and ambiguous desired state`() throws {
        #expect(
            throws: Institute.Repository.Policy.Fleet.Error.duplicateOrganization("swift-institute")
        ) {
            try Self.fleet(
                organizations: """
                    {"name":"swift-institute","layer":"control","status":"active"},
                    {"name":"swift-institute","layer":"control","status":"active"}
                    """
            )
        }
        #expect(throws: Institute.Repository.Policy.Fleet.Error.invalidLayer("L5")) {
            try Self.fleet(
                organizations: #"{"name":"swift-institute","layer":"L5","status":"active"}"#
            )
        }
        #expect(throws: Institute.Repository.Policy.Fleet.Error.invalidStatus("enabled")) {
            try Self.fleet(
                organizations:
                    #"{"name":"swift-institute","layer":"control","status":"enabled"}"#
            )
        }
        #expect(
            throws: Institute.Repository.Policy.Fleet.Error.malformedRepository("swift-institute")
        ) {
            try Self.fleet(
                organizations:
                    #"{"name":"swift-institute","layer":"control","status":"active"}"#,
                repositories: #"{"name":"swift-institute"}"#
            )
        }
        #expect(
            throws: Institute.Repository.Policy.Fleet.Error.inactiveOrganization("swift-institute")
        ) {
            try Self.fleet(
                organizations:
                    #"{"name":"swift-institute","layer":"control","status":"inactive"}"#,
                repositories: #"{"name":"swift-institute/example"}"#
            )
        }
        #expect(
            throws: Institute.Repository.Policy.Fleet.Error.duplicateRepository("swift-institute/example")
        ) {
            try Self.fleet(
                organizations:
                    #"{"name":"swift-institute","layer":"control","status":"active"}"#,
                repositories: """
                    {"name":"swift-institute/example"},
                    {"name":"swift-institute/example"}
                    """
            )
        }
    }

    private static func fleet(
        organizations: String,
        repositories: String? = nil
    ) throws -> Institute.Repository.Policy.Fleet {
        let repositoryField = repositories.map { ",\"repositories\":[\($0)]" } ?? ""
        let path = try BranchPinFoundation.writeTemporaryFleetPolicy(
            "{\"schemaVersion\":1,\"organizations\":[\(organizations)]\(repositoryField)}"
        )
        return try Institute.Repository.Policy.Fleet.read(at: path)
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
