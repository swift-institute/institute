#if LinterRuleBuildErrors
    public import Lint

    extension Lint.Build.Arguments {

        public enum Error: Swift::Error, Sendable, Equatable {
            case missing(option: Swift::String)
            case unknown(option: Swift::String)
            case noFiles
        }
    }

    extension Lint.Build.Arguments.Error: Swift::CustomStringConvertible {

        public var description: Swift::String {
            switch self {
            case .missing(let option): "\(option) is missing or has no value"
            case .unknown(let option): "unknown option \(option)"
            case .noFiles: "no file to check"
            }
        }
    }
#endif
