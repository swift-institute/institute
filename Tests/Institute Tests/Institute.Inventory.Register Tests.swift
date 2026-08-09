import Foundation
import Git_Foundation
import Testing

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Inventory.Test.Integration {
    @Test
    func `The register view leaves committed inventory bytes and worktree unchanged`() throws {
        let configuration = Institute.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-alpha-primitives",
                    url:
                        "https://github.com/swift-primitives/swift-alpha-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                ),
                .init(
                    name: "swift-rfc-9110",
                    url: "https://github.com/swift-ietf/swift-rfc-9110.git",
                    organization: "swift-ietf",
                    layer: .standards
                ),
            ]
        )
        let fixture = try Institute.Inventory.Test.Fixture(
            configuration: configuration
        )
        defer { fixture.remove() }
        let before = try Data(contentsOf: fixture.file)
        let document = try Institute.Configuration.Document.load(at: fixture.root)

        let register = Institute.Inventory.Register(
            repositories: document.configuration.repositories
        )

        #expect(
            register.description == """
                inventory: 2 repositories (name → organization → path)
                  swift-alpha-primitives → swift-primitives → swift-primitives/swift-alpha-primitives
                  swift-rfc-9110 → swift-ietf → swift-standards/swift-ietf/swift-rfc-9110
                """
        )
        #expect(try Data(contentsOf: fixture.file) == before)
        #expect(try fixture.git.status(at: fixture.location.path).isEmpty)
    }
}
