public import Command
public import Command_Schema
import Environment
public import Institute_Build_Coordinator
public import Institute_Model
import Process

extension Institute.Package.Command {
    /// `institute package build|test` — coordinated build or test.
    public struct Execute: Sendable, Command_Schema.Command.`Protocol` {
        public var action: Institute.Build.Action
        public var packagePath: Swift.String
        public var fresh: Bool
        public var jobs: Swift.Int?
        public var arguments: [Swift.String]

        public init(
            action: Institute.Build.Action = .build,
            packagePath: Swift.String = "",
            fresh: Bool = false,
            jobs: Swift.Int? = nil,
            arguments: [Swift.String] = []
        ) {
            self.action = action
            self.packagePath = packagePath
            self.fresh = fresh
            self.jobs = jobs
            self.arguments = arguments
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "execute", abstract: "Build or test one package via the coordinator.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.packagePath,
                    name: .long(.literal("package-path")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Package root for the operation (defaults to PWD)."
                    )
                )
                Command_Schema.Command.Flag(
                    \.fresh,
                    name: .long(.literal("fresh")),
                    help: .init(
                        abstract: "Use isolated build state — a scratch directory."
                    )
                )
                Command_Schema.Command.Option(
                    \.jobs,
                    name: .long(.literal("jobs")),
                    placeholder: "n",
                    help: .init(
                        abstract:
                            "Cap compile jobs the coordinator gives SwiftPM; defaults to the "
                            + "machine's processor count."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.arguments,
                    name: .long(.literal("argument")),
                    placeholder: "swiftpm-argument",
                    help: .init(
                        abstract: "Argument forwarded to SwiftPM (repeatable)."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            guard let working = Environment.read("PWD") else {
                throw .configuration("PWD is not available")
            }
            let status: Swift.Int32
            do throws(Institute.Build.Error) {
                status = try Institute.Build.Coordinator(jobs: jobs).run(
                    action,
                    at: packagePath.isEmpty ? working : packagePath,
                    fresh: fresh,
                    arguments: arguments
                )
            } catch {
                throw .process("\(error)")
            }
            Process.Exit.normal(status)
        }
    }

    /// `institute package run|resolve|update|clean|dump-package` — one
    /// forwarded SwiftPM administration verb through the coordinator.
    public struct Forward: Sendable, Command_Schema.Command.`Protocol` {
        public var action: Institute.Build.Action
        public var packagePath: Swift.String
        public var arguments: [Swift.String]

        public init(
            action: Institute.Build.Action = .resolve,
            packagePath: Swift.String = "",
            arguments: [Swift.String] = []
        ) {
            self.action = action
            self.packagePath = packagePath
            self.arguments = arguments
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "forward", abstract: "Forward one SwiftPM verb via the coordinator.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.packagePath,
                    name: .long(.literal("package-path")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Package root for the operation (defaults to PWD)."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.arguments,
                    name: .long(.literal("argument")),
                    placeholder: "swiftpm-argument",
                    help: .init(
                        abstract: "Argument forwarded to SwiftPM (repeatable)."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            guard let working = Environment.read("PWD") else {
                throw .configuration("PWD is not available")
            }
            let status: Swift.Int32
            do throws(Institute.Build.Error) {
                status = try Institute.Build.Coordinator(jobs: nil).run(
                    action,
                    at: packagePath.isEmpty ? working : packagePath,
                    fresh: false,
                    arguments: arguments
                )
            } catch {
                throw .process("\(error)")
            }
            Process.Exit.normal(status)
        }
    }
}
