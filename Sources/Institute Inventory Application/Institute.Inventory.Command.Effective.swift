public import Command
public import Command_Schema
import Console
import File_System
public import Institute_Inventory
public import Institute_Model
import Process

extension Institute.Inventory.Command {
    /// `institute inventory effective` — derive and write the effective
    /// inventory report.
    public struct Effective: Sendable, Command_Schema.Command.`Protocol` {
        public var inventoryScope: Swift.String
        public var inventoryOutput: Swift.String
        public var inventoryPrivateRoster: Swift.String

        public init(
            inventoryScope: Swift.String = "",
            inventoryOutput: Swift.String = "",
            inventoryPrivateRoster: Swift.String = ""
        ) {
            self.inventoryScope = inventoryScope
            self.inventoryOutput = inventoryOutput
            self.inventoryPrivateRoster = inventoryPrivateRoster
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "effective", abstract: "Derive and write the effective inventory.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.inventoryScope,
                    name: .long(.literal("inventory-scope")),
                    placeholder: "public|effective",
                    help: .init(
                        abstract: "Which limbs the effective report combines."
                    )
                )
                Command_Schema.Command.Option(
                    \.inventoryOutput,
                    name: .long(.literal("inventory-output")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Where the effective inventory report is written."
                    )
                )
                Command_Schema.Command.Option(
                    \.inventoryPrivateRoster,
                    name: .long(.literal("inventory-private-roster")),
                    placeholder: "path",
                    help: .init(
                        abstract:
                            "A supplied private-limb roster document; replaces the live "
                            + "discovery pass."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Inventory.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            guard
                let scope = Institute.Inventory.Effective.Output.Scope(rawValue: inventoryScope)
            else {
                throw .configuration(
                    "inventory effective: --inventory-scope must be public or effective"
                )
            }
            guard !inventoryOutput.isEmpty else {
                throw .configuration("inventory effective: --inventory-output is required")
            }
            let outputPath: File.Path
            do throws(File.Path.Error) {
                outputPath = try File.Path(inventoryOutput)
            } catch {
                throw .configuration(
                    "inventory effective: --inventory-output is not a valid path: \(error)"
                )
            }

            // A supplied roster replaces the live pass entirely: the
            // caller holds credentials this process does not (per-org
            // App installation tokens), so it discovers and this
            // process digests. Refused under `--inventory-scope
            // public`, where there is no private limb to supply.
            if !inventoryPrivateRoster.isEmpty {
                guard scope == .effective else {
                    throw .configuration(
                        "inventory effective: --inventory-private-roster requires "
                            + "--inventory-scope effective."
                    )
                }
                let rosterPath: File.Path
                do throws(File.Path.Error) {
                    rosterPath = try File.Path(inventoryPrivateRoster)
                } catch {
                    throw .configuration(
                        "inventory effective: --inventory-private-roster is not a valid path: "
                            + "\(error)"
                    )
                }
                let roster: Institute.Inventory.Effective.Roster
                do throws(Institute.Inventory.Effective.Roster.Error) {
                    roster = try .read(rosterPath)
                } catch {
                    throw .configuration("inventory effective: \(error)")
                }
                let supplied: Institute.Inventory.Effective
                do throws(Institute.Inventory.Effective.Error) {
                    supplied = try .init(
                        public: configuration,
                        roster: roster,
                        policy: .institute()
                    )
                } catch {
                    throw .configuration("inventory effective: \(error)")
                }
                let report = Institute.Inventory.Effective.Output(
                    scope: scope,
                    effective: supplied,
                    residue: roster.unmeasured
                )
                try report.write(to: outputPath)
                let summary =
                    "inventory effective: scope \(scope.rawValue) from a supplied roster, "
                    + "\(report.combined.population.count) combined, "
                    + "\(report.unmeasured.count) unmeasured, wrote \(outputPath)\n"
                Console.Output.error(summary)
                Process.Exit.normal(report.exitCode)
            }

            let discovery: Institute.Inventory.Private.Discovery
            switch scope {
            case .public:
                // No private pass was requested; the report records the
                // limb as not-requested rather than as an empty
                // measurement.
                discovery = .init(repositories: [], exclusions: [], unmeasured: [])

            case .effective:
                throw .configuration(
                    "inventory effective requires --inventory-private-roster; "
                        + "the Institute application has no network transport"
                )
            }

            let effective: Institute.Inventory.Effective
            do throws(Institute.Inventory.Effective.Error) {
                effective = try .init(public: configuration, private: discovery)
            } catch {
                throw .configuration("inventory effective: \(error)")
            }
            let report = Institute.Inventory.Effective.Output(
                scope: scope,
                effective: effective,
                unmeasured: discovery.unmeasured
            )
            try report.write(to: outputPath)
            let summary =
                "inventory effective: scope \(scope.rawValue), "
                + "\(report.combined.population.count) combined, "
                + "\(report.unmeasured.count) unmeasured, wrote \(outputPath)\n"
            Console.Output.error(summary)
            Process.Exit.normal(report.exitCode)
        }
    }
}
