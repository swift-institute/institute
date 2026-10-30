public import Command
public import Command_Schema
public import Institute_Model
public import Institute_Version
import Process

extension Institute.Version.Command {
    /// `institute version tag` — tag each `main` head that passed CI with
    /// its repository's next development version.
    ///
    /// Prints one line per repository and exits 1 when any repository
    /// needs a person (a refusal or a failure), else 0.
    public struct Tag: Sendable, Command_Schema.Command.`Protocol` {
        public var organizations: [Swift.String]
        public var repositories: [Swift.String]
        public var backfill: Swift.Bool
        public var dryRun: Swift.Bool

        public init(
            organizations: [Swift.String] = [],
            repositories: [Swift.String] = [],
            backfill: Swift.Bool = false,
            dryRun: Swift.Bool = false
        ) {
            self.organizations = organizations
            self.repositories = repositories
            self.backfill = backfill
            self.dryRun = dryRun
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "tag",
                abstract: "Tag each main head that passed CI with its next development version.",
                discussion: """
                    The line is \(Institute.Version.Line.development.tag(Institute.Version.Line.development.floor)) \
                    and up. Without --org or --repository every Institute organization is swept. \
                    --backfill tags only repositories with no tag on the line yet. --dry-run writes \
                    nothing and prints the tag a real run would create. GH_TOKEN must grant \
                    contents: write for a real run.
                    """
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.organizations,
                    name: .long(.literal("org")),
                    placeholder: "organization",
                    help: .init(abstract: "Sweep every repository of this organization (repeatable).")
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.repositories,
                    name: .long(.literal("repository")),
                    placeholder: "owner/name",
                    help: .init(abstract: "Sweep only this repository (repeatable).")
                )
                Command_Schema.Command.Flag(
                    \.backfill,
                    name: .long(.literal("backfill")),
                    help: .init(abstract: "Tag only repositories that have no tag on the line yet.")
                )
                Command_Schema.Command.Flag(
                    \.dryRun,
                    name: .long(.literal("dry-run")),
                    help: .init(abstract: "Write nothing; print the tag a real run would create.")
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard organizations.isEmpty || repositories.isEmpty else {
                throw .validationFailed(reason: "pass --org or --repository, not both")
            }
            for organization in organizations where Institute.Organization(rawValue: organization) == nil {
                throw .validationFailed(reason: "--org \(organization) is not an Institute organization")
            }
            for repository in repositories where Institute.Repository.Coordinate(repository) == nil {
                throw .validationFailed(
                    reason: "--repository must be owner/name in an Institute organization, got \(repository)"
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let coordinates = Swift.Set(repositories.compactMap(Institute.Repository.Coordinate.init))
            let named = Swift.Set(organizations.compactMap(Institute.Organization.init(rawValue:)))
                .union(coordinates.map(\.organization))
            let selected = Institute.Organization.allCases.filter { named.isEmpty || named.contains($0) }
            let sweep = Institute.Version.Sweep(
                mode: backfill ? .backfill : .continuous,
                dryRun: dryRun,
                client: .github
            )
            let reports = sweep.run(selected, repositories: coordinates)
            for line in Self.table(reports, sweep: sweep) { print(line) }
            Process.Exit.normal(reports.contains(where: \.outcome.blocking) ? 1 : 0)
        }
    }
}

extension Institute.Version.Command.Tag {
    /// One line per repository, then one count per kind of outcome.
    static func table(_ reports: [Institute.Version.Report], sweep: Institute.Version.Sweep) -> [Swift.String] {
        func padded(_ text: Swift.String, _ width: Swift.Int) -> Swift.String {
            text + Swift.String(repeating: " ", count: Swift.max(1, width - text.count))
        }
        var lines = [
            "institute version tag: line \(sweep.line.stem)N from \(sweep.line.tag(sweep.line.floor)), "
                + "\(sweep.mode.rawValue)\(sweep.dryRun ? ", dry run" : "")"
        ]
        var counts: [Swift.String: Swift.Int] = [:]
        for report in reports {
            let (kind, detail) = describe(report.outcome)
            counts[kind, default: 0] += 1
            lines.append(
                padded(report.repository.description, 56)
                    + padded(report.head.map { Swift.String($0.prefix(12)) } ?? "-", 14)
                    + padded(kind, 11)
                    + detail
            )
        }
        lines.append(
            "total \(reports.count): "
                + counts.sorted(by: { $0.key < $1.key }).map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        )
        return lines
    }

    /// The outcome's kind and its one-line detail.
    static func describe(_ outcome: Institute.Version.Outcome) -> (Swift.String, Swift.String) {
        switch outcome {
        case .tagged(let tag): ("tagged", tag.name)
        case .planned(let tag): ("would-tag", tag.name)
        case .current(let tag): ("current", tag.name)
        case .versioned(let tag): ("versioned", "latest \(tag.name) at \(tag.commit.prefix(12))")
        case .skipped(let skip): ("skipped", skip.rawValue)
        case .waiting(let gate): ("waiting", gate == .pending ? "ci-ok pending on main" : "no ci-ok run on main")
        case .held(let conclusion): ("held", "ci-ok \(conclusion)")
        case .refused(let latest, let relation):
            ("refused", "main is \(relation.rawValue) of \(latest.name) at \(latest.commit.prefix(12))")
        case .contended(let tag, let existing):
            ("contended", "\(tag.name) already names \(existing.prefix(12))")
        case .failed(let error): ("failed", error.description)
        }
    }
}

extension Institute.Version.Command {
    /// `institute version organizations` — the organizations a sweep
    /// covers, `Institute.Organization` in declaration order, as one JSON
    /// array of names: the `version-tags` workflow's matrix, so the
    /// workflow carries no roster of its own.
    public struct Organizations: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "organizations", abstract: "Print the swept organizations as one JSON array.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {}
        }

        public mutating func run() async throws(Institute.Error) {
            print(Self.matrix)
        }

        /// `["swift-institute","swift-atoms",…]`. Organization names are
        /// lowercase letters and hyphens, so no character needs escaping.
        static var matrix: Swift.String {
            "[" + Institute.Organization.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ",") + "]"
        }
    }
}

extension Institute.Version {
    /// `institute version` — development versions of the Institute's packages.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case tag(Tag)
        case organizations(Organizations)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "version", abstract: "Tag the Institute's packages with development versions.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "tag",
                        help: .init(abstract: "Tag each main head that passed CI with its next version."),
                        initial: { .init() },
                        map: Self.tag
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "organizations",
                        help: .init(abstract: "Print the swept organizations as one JSON array."),
                        initial: { .init() },
                        map: Self.organizations
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .tag(var command):
                try await command.run()
                self = .tag(command)
            case .organizations(var command):
                try await command.run()
                self = .organizations(command)
            }
        }
    }
}
