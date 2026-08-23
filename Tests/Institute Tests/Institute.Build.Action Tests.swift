import Testing

@testable import Institute_Build_Coordinator
@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

@Suite
struct `Build Action Tests` {
    @Test
    func `build and test are direct Swift operations with isolated scratch support`() {
        #expect(Institute.Build.Action.build.command == ["swift", "build"])
        #expect(Institute.Build.Action.test.command == ["swift", "test"])
        #expect(Institute.Build.Action.build.acceptsFreshScratch)
        #expect(Institute.Build.Action.test.acceptsFreshScratch)
    }

    @Test
    func `package administration operations use the Swift package namespace`() {
        #expect(Institute.Build.Action.resolve.command == ["swift", "package", "resolve"])
        #expect(Institute.Build.Action.dumpPackage.command == ["swift", "package", "dump-package"])
        #expect(!Institute.Build.Action.resolve.acceptsFreshScratch)
    }

    @Test
    func `invocation owns concurrency and fresh build state`() throws {
        let invocation = try Institute.Build.Action.test.invocation(
            jobs: 3,
            scratchPath: "/tmp/workspace-scratch",
            arguments: ["--filter", "Unit"]
        )

        #expect(
            invocation == [
                "swift", "test",
                "-j", "3",
                "--scratch-path", "/tmp/workspace-scratch",
                "--filter", "Unit",
            ]
        )
    }

    @Test(arguments: [
        "--package-path",
        "--package-path=/tmp/other",
        "--scratch-path",
        "--build-path=/tmp/other",
        "--cache-path",
        "--config-path=/tmp/other",
        "--security-path",
        "-j",
        "-j8",
        "--jobs=8",
    ])
    func `forwarded arguments cannot override coordinator state`(
        argument: Swift.String
    ) {
        #expect(
            throws: Institute.Build.Error.configuration(
                "SwiftPM argument \(argument) is owned by the build coordinator"
            )
        ) {
            _ = try Institute.Build.Action.test.invocation(
                jobs: 3,
                scratchPath: nil,
                arguments: [argument]
            )
        }
    }
}
