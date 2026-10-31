#if LinterRuleBuildErrors
    public import Lint

    extension Lint.Build {

        /// What the tool is asked to check: the directory that file paths are made relative to, the Swift files, and the
        /// stamp file to write when no error was found.
        ///
        /// A build-tool plugin declares the stamp as the command's output, so the build system runs the check before it
        /// compiles the target and runs it again only when a source file changed. A failed check writes no stamp.
        public struct Arguments: Sendable, Equatable {

            public let root: Swift::String

            public let files: [Swift::String]

            public let stamp: Swift::String?

            public init(root: Swift::String, files: [Swift::String], stamp: Swift::String? = nil) {
                self.root = root
                self.files = files
                self.stamp = stamp
            }
        }
    }

    extension Lint.Build.Arguments {

        public static let usage: Swift::String = "usage: swift-linter-build-errors --root <directory> [--stamp <file>] <file.swift> ..."

        /// Reads `--root <directory>`, an optional `--stamp <file>` and the files. A call with no file is refused, since a build check that
        /// names nothing is a wiring mistake and not a clean result.
        public static func parse(_ arguments: [Swift::String]) throws(Error) -> Self {
            var root: Swift::String?
            var stamp: Swift::String?
            var files: [Swift::String] = []
            var remaining = arguments.makeIterator()
            while let argument = remaining.next() {
                if argument == "--root" {
                    guard let value = remaining.next() else { throw .missing(option: argument) }
                    root = value
                } else if argument == "--stamp" {
                    guard let value = remaining.next() else { throw .missing(option: argument) }
                    stamp = value
                } else if argument.hasPrefix("--") {
                    throw .unknown(option: argument)
                } else {
                    files.append(argument)
                }
            }
            guard let root else { throw .missing(option: "--root") }
            guard !files.isEmpty else { throw .noFiles }
            return Self(root: root, files: files, stamp: stamp)
        }
    }
#endif
