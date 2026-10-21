import Byte
public import Command
public import Command_Schema
import Console
import File_System
public import Institute_Model
import JSON
import Process

extension Institute.Planner.Command {
    /// `institute planner canary --publish-run <run>` — verify publish run
    /// `run` and the current planner, measure each canary repository with
    /// both, and write the comparison as evidence. Exits 0 when the
    /// candidate is adoptable, 1 when it differs, 2 when refused.
    public struct Canary: Sendable, Command_Schema.Command.`Protocol` {
        public var publication: Swift.String
        public var repositories: [Swift.String]
        public var workPath: Swift.String
        public var outputPath: Swift.String

        public init(
            publication: Swift.String = "",
            repositories: [Swift.String] = [],
            workPath: Swift.String = "",
            outputPath: Swift.String = ""
        ) {
            self.publication = publication
            self.repositories = repositories
            self.workPath = workPath
            self.outputPath = outputPath
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "canary",
                abstract: "Run a published planner against the current one.",
                discussion: """
                    Without --repository, the canaries are \
                    \(Institute.Planner.Canary.repositories.joined(separator: ", ")). \
                    --work-path must not exist yet; it defaults to a fresh temporary \
                    directory. --output-path defaults to evidence.json in the work path.
                    """
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.publication,
                    name: .long(.literal("publish-run")),
                    placeholder: "run-id"
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.repositories,
                    name: .long(.literal("repository")),
                    placeholder: "owner/name"
                )
                Command_Schema.Command.Option(
                    \.workPath,
                    name: .long(.literal("work-path")),
                    placeholder: "directory"
                )
                Command_Schema.Command.Option(
                    \.outputPath,
                    name: .long(.literal("output-path")),
                    placeholder: "evidence.json"
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard Institute.Planner.isRun(publication) else {
                throw .validationFailed(reason: "--publish-run must be a publish-planner run id")
            }
            guard Set(repositories).count == repositories.count else {
                throw .validationFailed(reason: "duplicate --repository")
            }
            guard workPath.isEmpty || workPath.hasPrefix("/") else {
                throw .validationFailed(reason: "--work-path must be absolute")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let configuration = try Institute.Configuration.load(
                at: Institute.Planner.Command.root().checkout
            )
            var selected: [Institute.Repository] = []
            for name in repositories.isEmpty ? Institute.Planner.Canary.repositories : repositories {
                guard
                    let repository = configuration.repositories.first(where: {
                        "\($0.organization)/\($0.name)" == name
                    })
                else {
                    throw .configuration("planner canary: \(name) is not in Institute.json")
                }
                selected.append(repository)
            }
            let work = try workPath.isEmpty ? Self.temporary() : workPath
            let workDirectory = try Self.path(work)
            guard !File(workDirectory).stat.exists else {
                throw .configuration("planner canary: --work-path \(work) already exists")
            }
            let evidence = Institute.Planner.Canary.evidence(
                run: publication,
                repositories: selected,
                work: work,
                xcode: try Self.xcode(),
                release: .github,
                consumer: .github,
                runner: .local
            )
            let output = outputPath.isEmpty ? "\(work)/evidence.json" : outputPath
            do throws(Institute.Planner.Error) {
                if !File(workDirectory).stat.exists { try Institute.Planner.directory(workDirectory) }
                try Institute.Planner.write(
                    [Byte](utf8: evidence.jsonString(pretty: true, sortKeys: true) + "\n"),
                    to: Institute.Planner.path(output)
                )
            } catch {
                throw .filesystem("planner canary: cannot write evidence: \(error)")
            }
            for line in Self.table(evidence, output: output) { print(line) }
            Process.Exit.normal(evidence.verdict.code)
        }
    }
}

extension Institute.Planner.Command.Canary {
    /// The human table: one row per canary, every difference, the verdict.
    static func table(_ evidence: Institute.Planner.Evidence, output: Swift.String) -> [Swift.String] {
        guard evidence.verdict != .refused else {
            return [
                "institute planner canary: publish run \(evidence.run) refused: \(evidence.refusal)",
                "verdict: refused (exit 2); evidence: \(output)",
            ]
        }
        func padded(_ text: Swift.String, _ width: Swift.Int) -> Swift.String {
            text + Swift.String(repeating: " ", count: max(1, width - text.count))
        }
        var lines = [
            "institute planner canary: publish run \(evidence.run), candidate \(evidence.revision)",
            padded("repository", 36) + padded("current", 12) + padded("candidate", 12)
                + padded("regressions", 13) + "improvements",
        ]
        for comparison in evidence.repositories {
            lines.append(
                padded(comparison.repository, 36)
                    + padded(comparison.current.status.rawValue, 12)
                    + padded(comparison.candidate.status.rawValue, 12)
                    + padded("\(comparison.differences.count(where: { $0.kind == .regression }))", 13)
                    + "\(comparison.differences.count(where: { $0.kind == .improvement }))"
            )
        }
        for comparison in evidence.repositories {
            for difference in comparison.differences {
                lines.append("\(difference.kind.rawValue): \(comparison.repository): \(difference.detail)")
            }
        }
        lines.append(
            "verdict: \(evidence.verdict.rawValue) (exit \(evidence.verdict.code)); evidence: \(output)"
        )
        return lines
    }

    /// The Xcode the canary measures with: /Applications/Xcode.app when it
    /// exists, otherwise the application `xcode-select -p` names.
    static func xcode() throws(Institute.Error) -> Swift.String {
        let standard = "/Applications/Xcode.app"
        if File(try path(standard)).stat.exists { return standard }
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/xcode-select",
                    arguments: ["-p"],
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            throw .process("planner canary: cannot run xcode-select: \(error)")
        }
        var developer = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        while developer.last == "\n" { developer.removeLast() }
        let suffix = "/Contents/Developer"
        guard output.status == .exited(code: 0), developer.hasSuffix(suffix) else {
            throw .configuration("planner canary: no Xcode at \(standard) and xcode-select names none")
        }
        return Swift.String(developer.dropLast(suffix.count))
    }

    /// A fresh path under the temporary directory for the work tree.
    static func temporary() throws(Institute.Error) -> Swift.String {
        let anchor: File.Path
        do throws(File.Path.Error) {
            anchor = try File.Path.Temporary.deterministic(
                prefix: "institute-planner-canary",
                key: "",
                suffix: ""
            )
        } catch {
            throw .filesystem("planner canary: cannot resolve a temporary directory: \(error)")
        }
        do throws(File.Path.Temporary.Error) {
            return try File.Path.Temporary.sibling(of: anchor, prefix: "institute-planner-canary-")
                .description
        } catch {
            throw .filesystem("planner canary: cannot mint a work path: \(error)")
        }
    }

    static func path(_ text: Swift.String) throws(Institute.Error) -> File.Path {
        do throws(Institute.Planner.Error) {
            return try Institute.Planner.path(text)
        } catch {
            throw .configuration("planner canary: \(error)")
        }
    }
}
