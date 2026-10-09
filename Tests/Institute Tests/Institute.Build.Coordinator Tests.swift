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
struct `Build Coordinator Tests` {
    @Test
    func `the default job count is the machine, not a constant`() {
        // It was hard-wired to 3. On this fleet's 8-core machines that ran
        // every coordinated build at ~37% of the host while holding a
        // machine-wide exclusive lock over the other five cores.
        #expect(Institute.Build.Coordinator().jobs == Institute.Build.Coordinator.processors)
        #expect(Institute.Build.Coordinator.processors >= 1)
    }

    @Test
    func `an explicit job count still wins`() {
        #expect(Institute.Build.Coordinator(jobs: 2).jobs == 2)
    }

    @Test
    func `an empty invocation is refused rather than run as a bare environment listing`() {
        var cleanups = 0
        #expect(throws: Institute.Build.Error.self) {
            _ = try Institute.Build.Coordinator().coordinated(
                [],
                in: "/",
                describing: "empty",
                cleanup: { error in
                    cleanups += 1
                    return error
                }
            )
        }
        #expect(cleanups == 1)
    }

    @Test(arguments: [0, -1, Swift.Int.min])
    func `a nonpositive job count clamps rather than producing an unrunnable invocation`(
        jobs: Swift.Int
    ) {
        // Clamped at construction so the invariant lives in one place. The
        // runner used to re-check this; it cannot fire now that no
        // `Coordinator` can hold a nonpositive count.
        #expect(Institute.Build.Coordinator(jobs: jobs).jobs == 1)
    }

    @Test
    func `the job count reaches SwiftPM`() throws {
        let invocation = try Institute.Build.Action.build.invocation(
            jobs: Institute.Build.Coordinator(jobs: 8).jobs,
            scratchPath: nil,
            arguments: []
        )

        #expect(invocation == ["swift", "build", "-j", "8"])
    }

    @Test(arguments: ["-j", "-j8", "--jobs", "--jobs=8"])
    func `a caller cannot supply its own job count, so the default is the only one`(
        argument: Swift.String
    ) {
        // The reason raising the default mattered rather than documenting a
        // workaround: `--argument -j8` does not override the coordinator, it
        // is rejected. Before this change there was no way to run a
        // coordinated build at anything other than 3.
        #expect(throws: Institute.Build.Error.self) {
            _ = try Institute.Build.Action.build.invocation(
                jobs: 3,
                scratchPath: nil,
                arguments: [argument]
            )
        }
    }
}
