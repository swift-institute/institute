public import Command
public import Command_Schema
import Console
import File_System
import Git_Foundation
import Institute_Doctor
public import Institute_Instruments
public import Institute_Model
import JSON
import Package_Manager
import Process

extension Institute.Certification.Command {
    /// `institute certification snapshot` — derive and print the frozen
    /// snapshot.
    public struct Snapshot: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "snapshot", abstract: "Derive and print the frozen snapshot.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Certification.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let git = Git.Client()
            let inventoryCommit: Institute.Certification.Revision
            let inventoryBlob: Swift.String
            var centrals = [Institute.Repository.Key: Institute.Certification.Revision]()
            var reading = root.checkout.description
            do {
                inventoryCommit = try .init(
                    git.head("HEAD", at: root.checkout.description).rawValue
                )
                inventoryBlob = try git.head(
                    "HEAD:Institute.json",
                    at: root.checkout.description
                ).rawValue
                // The control-plane member set named on
                // swift-institute/.github#600 (2026-08-18 population
                // reconciliation): governance repositories certified by
                // exact revision, never by implied package obligations.
                for name in [
                    ".github", "institute", "institute-application", "Issues", "Research",
                    "swift-institute.org",
                ] {
                    reading = "\(root.hierarchy)/\(name)"
                    guard
                        let key = Institute.Repository.Key(
                            identity: "swift-institute/\(name)"
                        )
                    else {
                        throw Institute.Error.repository(
                            "swift-institute/\(name) is not a canonical repository key"
                        )
                    }
                    centrals[key] = try .init(
                        git.head("main", at: "\(root.hierarchy)/\(name)").rawValue
                    )
                }
            } catch {
                throw .configuration(
                    "certification snapshot: cannot read exact heads at \(reading): \(error)"
                )
            }
            let snapshot = try Institute.Certification.Derivation(
                root: root,
                configuration: configuration
            ).snapshot(
                inventoryCommit: inventoryCommit,
                inventoryBlob: inventoryBlob,
                centrals: centrals,
                exclusions: []
            )
            print(snapshot.canonical)
            Console.Output.error(
                "certification snapshot: \(snapshot.members.count) members, "
                    + "\(snapshot.exclusions.count) exclusions, digest \(snapshot.digest)\n"
            )
            Process.Exit.normal(0)
        }
    }
}

extension Institute.Certification.Command {
    /// `institute certification run` — execute obligation accounts over a
    /// frozen snapshot.
    public struct Run: Sendable, Command_Schema.Command.`Protocol` {
        public var receiptPath: Swift.String
        public var fresh: Bool
        public var composed: Bool
        public var arguments: [Swift.String]

        public init(
            receiptPath: Swift.String = "",
            fresh: Bool = false,
            composed: Bool = false,
            arguments: [Swift.String] = []
        ) {
            self.receiptPath = receiptPath
            self.fresh = fresh
            self.composed = composed
            self.arguments = arguments
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "run", abstract: "Execute obligation accounts over a frozen snapshot.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.receiptPath,
                    name: .long(.literal("receipt")),
                    placeholder: "path",
                    help: .init(
                        abstract: "The frozen snapshot path this run evaluates."
                    )
                )
                Command_Schema.Command.Flag(
                    \.fresh,
                    name: .long(.literal("fresh")),
                    help: .init(
                        abstract:
                            "Evaluate ephemeral exact-revision clones (mutually exclusive "
                            + "with --composed)."
                    )
                )
                Command_Schema.Command.Flag(
                    \.composed,
                    name: .long(.literal("composed")),
                    help: .init(
                        abstract:
                            "Certify against isolated exact-snapshot checkouts — every package "
                            + "member is materialized as a certifier-owned detached checkout of "
                            + "exactly its snapshot revision, and every internal edge resolves "
                            + "to one of those trees; no developer worktree is an evaluation "
                            + "source (mutually exclusive with --fresh)."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.arguments,
                    name: .long(.literal("argument")),
                    placeholder: "obligation-identity",
                    help: .init(
                        abstract: "Select only this obligation identity (repeatable)."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !receiptPath.isEmpty else {
                throw .validationFailed(
                    reason:
                        "certification run and assemble require --receipt "
                        + "(the frozen snapshot path)."
                )
            }
            guard !fresh || !composed else {
                throw .validationFailed(
                    reason:
                        "--fresh and --composed are mutually exclusive evaluation profiles."
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Certification.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let snapshot = try Institute.Certification.Command.snapshot(atPath: receiptPath)
            let platform = Institute.Certification.Command.platform
            let policy = try Institute.Certification.Command.policy(platform: platform)
            var obligations = Institute.Certification.Obligation.derive(
                from: snapshot,
                policy: policy
            )
            if !arguments.isEmpty {
                let selected = Set(arguments)
                obligations = obligations.filter { selected.contains($0.key.identity) }
            }
            let accounts: [Institute.Certification.Account]
            var coverageFailures = 0
            if fresh {
                // Ephemeral exact-revision evaluation: clone each member
                // from its local materialization, prove the clone is at
                // the snapshot revision, fresh-resolve so internal edges
                // pin current tips (= snapshot at freeze time), execute,
                // read closure, delete. No shared tree is mutated.
                let evaluation = Institute.Certification.Ephemeral.accounts(
                    obligations: obligations,
                    snapshot: snapshot,
                    root: root,
                    configuration: configuration,
                    platform: platform,
                    emit: { print($0) },
                    diagnose: { Console.Output.error($0) }
                )
                accounts = evaluation.accounts
                coverageFailures = evaluation.coverageFailures
            } else if composed {
                // Composed exact-S evaluation: refuse unless every
                // package member's materialization stands at exactly
                // its snapshot revision, then verify each member with
                // every internal edge redirected to its local checkout
                // through one source-map transaction per member.
                let evaluation = try Institute.Certification.Composed.accounts(
                    obligations: obligations,
                    snapshot: snapshot,
                    root: root,
                    configuration: configuration,
                    platform: platform,
                    emit: { print($0) },
                    diagnose: { Console.Output.error($0) }
                )
                accounts = evaluation.accounts
                coverageFailures = evaluation.coverageFailures
            } else {
                let execution = Institute.Certification.Execution(
                    root: root,
                    configuration: configuration,
                    platform: platform
                )
                accounts = execution.accounts(for: obligations, in: snapshot)
            }
            for account in accounts {
                print(account.json.serialize(sortKeys: true))
            }
            // Law-2 closure coverage: read back each selected member's
            // resolved state and classify every governed edge. Under
            // --fresh the ephemeral evaluator already emitted coverage
            // from each clone's own resolution; under --composed the
            // composed evaluator did, from each member's own resolution.
            var repositories = [Swift.String: Institute.Repository]()
            for repository in configuration.repositories {
                repositories["\(repository.organization)/\(repository.name)"] =
                    repository
            }
            let packages = Package.Manager()
            for identity in fresh || composed ? [] : Set(accounts.map(\.obligation.key)) {
                guard let repository = repositories[identity.identity] else { continue }
                let directory: File.Directory
                do throws(Institute.Error) {
                    directory = try root.materialization(for: repository)
                } catch {
                    Console.Output.error(
                        "closure: \(identity.identity): no readable materialization — "
                            + "UNMEASURED\n"
                    )
                    coverageFailures += 1
                    continue
                }
                let resolution: Package.Resolution
                do {
                    resolution = try packages.resolution(at: directory.description)
                } catch {
                    Console.Output.error(
                        "closure: \(identity.identity): resolution unreadable — "
                            + "UNMEASURED\n"
                    )
                    coverageFailures += 1
                    continue
                }
                let coverage = try Institute.Certification.Closure.Coverage(
                    consumer: identity,
                    proofs: Institute.Certification.Closure.proofs(
                        consumer: identity,
                        resolution: resolution,
                        snapshot: snapshot
                    )
                )
                print(coverage.json.serialize(sortKeys: true))
                if !coverage.passes { coverageFailures += 1 }
            }
            let met = accounts.filter {
                if case .met = $0.outcome { true } else { false }
            }.count
            let failed = accounts.filter {
                if case .failed = $0.outcome { true } else { false }
            }.count
            Console.Output.error(
                "certification run: \(accounts.count) obligations, \(met) met, "
                    + "\(failed) failed, \(accounts.count - met - failed) unmeasured, "
                    + "\(coverageFailures) closure failures\n"
            )
            Process.Exit.normal(
                failed == 0 && met == accounts.count && coverageFailures == 0 ? 0 : 1
            )
        }
    }
}

extension Institute.Certification.Command {
    /// `institute certification assemble` — bind captured evidence into
    /// one structurally complete certificate.
    public struct Assemble: Sendable, Command_Schema.Command.`Protocol` {
        public var receiptPath: Swift.String
        public var evidencePath: Swift.String

        public init(
            receiptPath: Swift.String = "",
            evidencePath: Swift.String = ""
        ) {
            self.receiptPath = receiptPath
            self.evidencePath = evidencePath
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "assemble", abstract: "Bind captured evidence into one certificate.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.receiptPath,
                    name: .long(.literal("receipt")),
                    placeholder: "path",
                    help: .init(
                        abstract: "The frozen snapshot path this assembly evaluates."
                    )
                )
                Command_Schema.Command.Option(
                    \.evidencePath,
                    name: .long(.literal("evidence")),
                    placeholder: "path",
                    help: .init(
                        abstract:
                            "Evidence JSONL file this assembly reads — one JSON line per "
                            + "account or closure coverage, as `certification run` prints them."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !receiptPath.isEmpty else {
                throw .validationFailed(
                    reason:
                        "certification run and assemble require --receipt "
                        + "(the frozen snapshot path)."
                )
            }
            guard !evidencePath.isEmpty else {
                throw .validationFailed(
                    reason:
                        "certification assemble requires --evidence "
                        + "(the captured account/coverage JSONL path)."
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Certification.Command.root()
            // Assembly reports; it does not judge. The evidence file is
            // the captured stdout of one or more `certification run`
            // invocations over the same frozen snapshot; assembly binds
            // it into one structurally complete certificate whose
            // honest verdict may be unmeasured or failed. Obligations
            // derive exactly as run mode derives them — an obligation
            // with no evidence is accounted UNMEASURED, never dropped.
            let snapshot = try Institute.Certification.Command.snapshot(atPath: receiptPath)
            let platform = Institute.Certification.Command.platform
            let policy = try Institute.Certification.Command.policy(platform: platform)
            let obligations = Institute.Certification.Obligation.derive(
                from: snapshot,
                policy: policy
            )
            let evidenceText = try Institute.Certification.Command.fileContents(
                atPath: evidencePath,
                describedAs: "--evidence"
            )
            let evidence = try Evidence.parse(evidenceText)
            if evidence.replacedCoverage > 0 {
                Console.Output.error(
                    "certification assemble: \(evidence.replacedCoverage) closure "
                        + "coverage record(s) replaced by a later line for the same "
                        + "consumer\n"
                )
            }
            var accounts = evidence.accounts
            let accounted = Set(accounts.map(\.obligation))
            for obligation in obligations where !accounted.contains(obligation) {
                accounts.append(
                    .init(
                        obligation: obligation,
                        outcome: .unmeasured(reason: "no account in assembled evidence")
                    )
                )
            }
            // The control names the producer attributably: the exact
            // institute-application revision this assembly ran from,
            // and the observed toolchain. Purely local assembly carries
            // no hosted CI policy and no runtime receipts.
            let certifier: Institute.Certification.Revision
            do {
                certifier = try .init(
                    Git.Client().head("HEAD", at: root.checkout.description).rawValue
                )
            } catch {
                throw .configuration(
                    "certification assemble: cannot read the producing revision at "
                        + "\(root.checkout): \(error)"
                )
            }
            // Descriptive, never gating: assembly must not fail because
            // it could not identify its own toolchain string.
            let toolchain: Swift.String
            do throws(Institute.Error) {
                let observed = try Institute.Doctor.spawn(
                    "swift",
                    arguments: ["--version"]
                )
                toolchain =
                    observed.split(separator: "\n").first.map(Swift.String.init)
                    ?? "unknown"
            } catch {
                toolchain = "unknown"
            }
            let certificate: Institute.Certification.Certificate
            do throws(Institute.Error) {
                certificate = try .init(
                    snapshot: snapshot,
                    control: .init(
                        certifier: certifier,
                        toolchain: toolchain,
                        policy: nil,
                        runtimeReceipts: []
                    ),
                    policy: policy,
                    obligations: obligations,
                    accounts: accounts,
                    exceptions: [],
                    closure: evidence.coverage,
                    coherenceReceipts: []
                )
            } catch {
                throw .configuration(
                    "certification assemble: structurally invalid certificate: \(error)"
                )
            }
            print(certificate.canonical)
            Console.Output.error(
                "certificate digest: \(certificate.digest)"
                    + "  verdict: \(certificate.verdict.rawValue)\n"
            )
            Process.Exit.normal(0)
        }
    }
}

extension Institute.Certification {
    /// `institute certification` — the certification verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case snapshot(Snapshot)
        case run(Run)
        case assemble(Assemble)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "certification", abstract: "Derive, execute, and assemble certification.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "snapshot",
                        help: .init(abstract: "Derive and print the frozen snapshot."),
                        initial: { Snapshot() },
                        map: Self.snapshot
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "run",
                        help: .init(abstract: "Execute obligation accounts over a snapshot."),
                        initial: { Run() },
                        map: Self.run
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "assemble",
                        help: .init(abstract: "Bind captured evidence into one certificate."),
                        initial: { Assemble() },
                        map: Self.assemble
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .snapshot(var command):
                try await command.run()
                self = .snapshot(command)
            case .run(var command):
                try await command.run()
                self = .run(command)
            case .assemble(var command):
                try await command.run()
                self = .assemble(command)
            }
        }
    }
}
