public import Async_Fanout
internal import Kernel_System
internal import Kernel_Thread

// Bounded concurrent evaluation of independent work is owned by swift-async
// as `Async.Fanout`, and every consumer imports that product directly — the
// Institute alias that used to stand in front of it is deleted (Amendment 6
// partition supplement, clause 1). What remains here is the sole
// Institute-specific residue: the online processor-count default, read
// through the kernel.

extension Async.Fanout {
    /// The online processor count.
    ///
    /// Read from the machine rather than fixed, so a fan-out neither
    /// under-uses a large host nor oversubscribes a small one.
    public static var processors: Swift.Int {
        Swift.Int(Kernel.Thread.Count(System.Processor.count))
    }

    /// Every fan-out in this application spawns a child process per item —
    /// `git`, `swift package dump-package`, the linter runner — so an
    /// unspecified bound defaults to the online processor count.
    public init(jobs: Swift.Int? = nil) {
        self.init(jobs: jobs ?? Self.processors)
    }
}
