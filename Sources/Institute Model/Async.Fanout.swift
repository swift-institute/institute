public import Async_Fanout
internal import Kernel_System

extension Async.Fanout {
    /// The online processor count.
    ///
    /// Read from the machine rather than fixed, so a fan-out neither
    /// under-uses a large host nor oversubscribes a small one.
    public static var processors: Swift.Int {
        Swift.Int(CPU.Logical.count)
    }

    /// Every fan-out in this application spawns a child process per item —
    /// `git`, `swift package dump-package`, the linter runner — so an
    /// unspecified bound defaults to the online processor count.
    public init(jobs: Swift.Int? = nil) {
        self.init(jobs: jobs ?? Self.processors)
    }
}
