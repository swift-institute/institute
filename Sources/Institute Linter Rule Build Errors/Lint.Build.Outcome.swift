#if LinterRuleBuildErrors
    public import Lint

    extension Lint.Build {

        /// What the tool prints, one line each, the status it exits with: 0 when no error was found, 1 when one was,
        /// and 64 when the arguments were refused, and the stamp file to write, which is set only when no error was found.
        public struct Outcome: Sendable, Equatable {

            public let lines: [Swift::String]

            public let status: Swift::Int32

            public let stamp: Swift::String?

            public init(lines: [Swift::String], status: Swift::Int32, stamp: Swift::String? = nil) {
                self.lines = lines
                self.status = status
                self.stamp = stamp
            }
        }
    }
#endif
