public import Command
public import Command_Schema
import Console
import Git_Foundation
public import Institute_Model
import JSON
import Process

extension Institute.Planner.Command {
    /// `institute planner adopt --publish-run <run> --evidence-path <evidence>
    /// --github-checkout <path>` — append publish run `run`'s PIN lines to
    /// the checkout's `.institute-ci-planner`, pin its revision in
    /// `.institute-ci-pin`, verify the result against the contract, and
    /// record it as one local commit. Refuses (exit 2) unless the evidence
    /// is an adoptable canary of the same run. Never pushes: it prints the
    /// push for a human to run after their go.
    public struct Adopt: Sendable, Command_Schema.Command.`Protocol` {
        public var publication: Swift.String
        public var evidencePath: Swift.String
        public var checkout: Swift.String

        public init(
            publication: Swift.String = "",
            evidencePath: Swift.String = "",
            checkout: Swift.String = ""
        ) {
            self.publication = publication
            self.evidencePath = evidencePath
            self.checkout = checkout
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "adopt", abstract: "Commit an adoptable planner to the consumer checkout.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.publication,
                    name: .long(.literal("publish-run")),
                    placeholder: "run-id"
                )
                Command_Schema.Command.Option(
                    \.evidencePath,
                    name: .long(.literal("evidence-path")),
                    placeholder: "evidence.json"
                )
                Command_Schema.Command.Option(
                    \.checkout,
                    name: .long(.literal("github-checkout")),
                    placeholder: "swift-institute/.github"
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard Institute.Planner.isRun(publication) else {
                throw .validationFailed(reason: "--publish-run must be a publish-planner run id")
            }
            guard !evidencePath.isEmpty else {
                throw .validationFailed(reason: "--evidence-path is required")
            }
            guard checkout.hasPrefix("/") else {
                throw .validationFailed(reason: "--github-checkout must be an absolute path")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            do throws(Institute.Planner.Error) {
                let adoption = try Institute.Planner.Adoption(
                    evidence: try evidence(),
                    run: publication,
                    pin: try .init(text: text(Institute.Planner.Consumer.pin)),
                    ledger: try .init(text: text(Institute.Planner.Consumer.ledger)),
                    release: .github
                )
                let commit = try adoption.record(at: checkout)
                print(
                    "institute planner adopt: committed \(commit.rawValue) in \(checkout): "
                        + "planner \(adoption.revision) from publish run \(publication)"
                )
                print("Nothing was pushed. After a go, publish it with:")
                print(Institute.Planner.Adoption.push(checkout))
            } catch {
                Console.Output.error("institute planner adopt: refused: \(error)\n")
                Process.Exit.normal(2)
            }
        }

        private func evidence() throws(Institute.Planner.Error) -> Institute.Planner.Evidence {
            let bytes = try Institute.Planner.read(Institute.Planner.path(evidencePath))
            do throws(JSON.Error) {
                return try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
            } catch {
                throw .evidence("\(evidencePath) is not planner canary evidence: \(error)")
            }
        }

        private func text(_ name: Swift.String) throws(Institute.Planner.Error) -> Swift.String {
            Swift.String(
                decoding: try Institute.Planner.read(Institute.Planner.path("\(checkout)/\(name)")),
                as: Swift.UTF8.self
            )
        }
    }
}
