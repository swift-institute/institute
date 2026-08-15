import File_System
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Peer.Layout {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Peer.Layout.Test.Unit {
    @Test
    func `an organization repository nests under its organization`() {
        let repository = Institute.Peer.Repository(
            name: "burgerlijk-wetboek-boek-2",
            url: "https://github.com/swift-nl-wetgever/burgerlijk-wetboek-boek-2.git",
            organization: "swift-nl-wetgever"
        )

        #expect(
            Institute.Peer.Layout.reference(for: repository, in: "rule-institute")
                == "swift-nl-wetgever/burgerlijk-wetboek-boek-2"
        )
    }

    @Test
    func `an eponymous-organization repository sits directly under the peer root`() {
        let repository = Institute.Peer.Repository(
            name: "Internal",
            url: "https://github.com/rule-institute/Internal.git",
            organization: "rule-institute"
        )

        #expect(
            Institute.Peer.Layout.reference(for: repository, in: "rule-institute")
                == "Internal"
        )
    }

    @Test
    func `directory descends from the peer root through the layout components`() throws {
        let root = try File.Directory(validating: "/scratch")
        let repository = Institute.Peer.Repository(
            name: "rule-law",
            url: "https://github.com/rule-law/rule-law.git",
            organization: "rule-law"
        )

        let directory = try Institute.Peer.Layout.directory(
            for: repository,
            in: "rule-institute",
            at: root
        )

        #expect(directory.description == "/scratch/rule-law/rule-law")
    }
}

extension Institute.Peer.Layout.Test.`Edge Case` {
    @Test(arguments: ["rule/evil", ".", ".."])
    func `an invalid layout component is a configuration error, not a silent path`(
        name: Swift.String
    ) {
        let repository = Institute.Peer.Repository(
            name: name,
            url: "https://github.com/rule-law/\(name).git",
            organization: "rule-law"
        )

        #expect(throws: Institute.Error.self) {
            _ = try Institute.Peer.Layout.directory(
                for: repository,
                in: "rule-institute",
                at: try File.Directory(validating: "/scratch")
            )
        }
    }
}
