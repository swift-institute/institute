public import Institute_CI_Canon
public import Institute_CI_Model
public import Institute_CI_Validation
public import Institute_Model

extension Institute.CI.Command {
    /// The portable process seam for complete Gitignore policy rendering and
    /// validation. It owns argument grammar and wire encoding only; canon,
    /// predicate, fixture discovery, and controls remain with their existing
    /// owners.
    public enum Gitignore {
        public enum Action: Sendable, Equatable {
            case render(canon: String, target: String?)
            case validate(repository: String, root: String, canon: String?)
            case fixtures(corpus: String)
        }

        public enum Error: Swift.Error, Sendable, Equatable {
            case missingCommand
            case unknownCommand(String)
            case missingValue(String)
            case unknownArgument(String)
            case duplicateArgument(String)
            case missingRequiredArgument(String)
            case invalidCanon(String)

            public var message: String {
                switch self {
                case .missingCommand:
                    "expected render-gitignore, validate-gitignore, or validate-gitignore-fixtures"

                case .unknownCommand(let command):
                    "unknown command `\(command)`"

                case .missingValue(let option):
                    "\(option) requires a value"

                case .unknownArgument(let argument):
                    "unknown argument `\(argument)`"

                case .duplicateArgument(let option):
                    "\(option) may appear once"

                case .missingRequiredArgument(let option):
                    "missing required \(option)"

                case .invalidCanon(let message):
                    message
                }
            }
        }

        /// Parses one of the three control-plane operations. Values are kept
        /// as paths here so the caller decides its own filesystem boundary.
        public static func parse(_ arguments: [String]) throws(Error) -> Action {
            guard let command = arguments.first else { throw .missingCommand }
            switch command {
            case "render-gitignore":
                let values = try values(arguments.dropFirst(), admitting: ["--canon", "--target"])
                guard let canon = values["--canon"] else {
                    throw .missingRequiredArgument("--canon")
                }
                return .render(canon: canon, target: values["--target"])

            case "validate-gitignore":
                let values = try values(
                    arguments.dropFirst(),
                    admitting: ["--repository", "--root", "--canon"]
                )
                guard let repository = values["--repository"] else {
                    throw .missingRequiredArgument("--repository")
                }
                guard let root = values["--root"] else { throw .missingRequiredArgument("--root") }
                return .validate(repository: repository, root: root, canon: values["--canon"])

            case "validate-gitignore-fixtures":
                let values = try values(arguments.dropFirst(), admitting: ["--corpus"])
                guard let corpus = values["--corpus"] else {
                    throw .missingRequiredArgument("--corpus")
                }
                return .fixtures(corpus: corpus)

            default:
                throw .unknownCommand(command)
            }
        }

        /// Renders the complete canonical policy. `target` is deliberately
        /// read-only input: there is no handwritten tail to preserve.
        public static func render(canon: String, target: String?) throws(Error) -> String {
            do throws(Institute.CI.Canon.Gitignore.Render.Error) {
                return try Institute.CI.Canon.Gitignore.Render(
                    canon: .init(canon)
                )(over: target.map(Institute.CI.Canon.Gitignore.init))
            } catch {
                throw .invalidCanon(error.message)
            }
        }

        /// Evaluates one checked-out repository. Findings remain the shared
        /// TSV wire format so every GH-IGNORE identifier survives aggregation.
        public static func findings(
            repository: String,
            root: String,
            canon: String?
        ) throws(Institute.CI.Validation.EnvironmentDefect)
            -> [Institute.CI.Validation.Finding]
        {
            try Institute.CI.Validation.Gitignore(canon: canon)
                .findings(in: .init(repository: repository, root: root))
        }

        public static func encoded(
            findings: [Institute.CI.Validation.Finding]
        ) -> String {
            findings.map(\.tsv).joined(separator: "\n")
                + (findings.isEmpty ? "" : "\n")
        }

        /// Runs only this package's Gitignore corpus through the shared
        /// harness. Its fail scenarios and positive controls make an empty
        /// finding stream non-evidence rather than a pass.
        public static func fixtures(
            corpus: String
        ) throws(Institute.CI.Validation.EnvironmentDefect)
            -> Institute.CI.Validation.Harness.Report
        {
            try Institute.CI.Validation.Harness(
                corpus: .init(root: corpus),
                validators: [Institute.CI.Validation.Gitignore()]
            ).run(matching: "gh-ignore-")
        }

        private static func values(
            _ arguments: ArraySlice<String>,
            admitting options: Set<String>
        ) throws(Error) -> [String: String] {
            var values: [String: String] = [:]
            var iterator = arguments.makeIterator()
            while let option = iterator.next() {
                guard options.contains(option) else { throw .unknownArgument(option) }
                guard let value = iterator.next(), !value.hasPrefix("--") else {
                    throw .missingValue(option)
                }
                guard values[option] == nil else { throw .duplicateArgument(option) }
                values[option] = value
            }
            return values
        }
    }
}
