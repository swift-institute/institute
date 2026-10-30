import Institute_Model
import Testing

@testable import Institute_Version

extension Institute.Version.Line {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Version.Line.Test.Unit {
    @Test func `the development line starts at 0.0.100`() {
        let line = Institute.Version.Line.development
        #expect(line.stem == "0.0.")
        #expect(line.tag(line.next(after: [])) == "0.0.100")
    }

    @Test func `the next ordinal is one above the highest, in any order`() {
        let line = Institute.Version.Line.development
        #expect(line.next(after: [100]) == 101)
        #expect(line.next(after: [100, 103, 101]) == 104)
    }

    @Test func `a tag below the floor never pulls the line under it`() {
        #expect(Institute.Version.Line.development.next(after: [4]) == 100)
    }

    @Test func `a pre-release line renders and reads its own tags only`() {
        let line = Institute.Version.Line.prerelease(major: 0, minor: 19, patch: 0, identifier: "dev", floor: 1)
        #expect(line.tag(line.next(after: [])) == "0.19.0-dev.1")
        #expect(line.ordinal(of: "0.19.0-dev.7") == 7)
        #expect(line.ordinal(of: "0.0.100") == nil)
        #expect(Institute.Version.Line.development.ordinal(of: "0.19.0-dev.7") == nil)
    }
}

extension Institute.Version.Line.Test.`Edge Case` {
    @Test(arguments: [
        "ci-binaries", "0.0.", "0.0.0100", "v0.0.100", "0.0.100-dev.1", "0.0.100+build", "0.1.100", "0.0.1a",
    ])
    func `a name that is not exactly stem plus ordinal is off the line`(_ tag: Swift.String) {
        #expect(Institute.Version.Line.development.ordinal(of: tag) == nil)
    }

    @Test func `ordinals on the line read back`() {
        let line = Institute.Version.Line.development
        #expect(line.ordinal(of: "0.0.100") == 100)
        #expect(line.ordinal(of: "0.0.4") == 4)
        #expect(line.ordinal(of: "0.0.0") == 0)
    }
}
