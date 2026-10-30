import Byte
import Institute_Command
public import Institute_Model
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy BrokenSymlink Tests` {
    @Test
    func `only missing targets are findings`() throws {
        let root = BrokenSymlinkFixture()
        try root.createDirectory()
        defer { root.remove() }

        #expect(root.createEmptyTarget())
        try root.linkLiveToTarget()
        try root.linkBrokenToMissing()

        let findings = try Institute.Repository.Policy.BrokenSymlink.findings(at: root.path)

        #expect(findings == [.init(path: "broken")])
    }
}
