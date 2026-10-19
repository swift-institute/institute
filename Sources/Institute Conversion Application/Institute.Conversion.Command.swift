import Byte
public import Command
public import Command_Schema
import Console
import Environment
import File_System
public import Institute_Conversion
public import Institute_Model
import JSON

extension Institute.Conversion.Command {
    /// Resolves the Institute root from the working directory.
    static func root() throws(Institute.Error) -> Institute.Root {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        return try Institute.Root(checkout: checkout)
    }
}

extension Institute.Conversion.Command {
    /// `institute conversion seal` — seal the conversion receipt.
    public struct Seal: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "seal", abstract: "Seal the conversion receipt over the selection.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Conversion.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let selection = try Institute.Selection.effective(
                at: root.checkout,
                in: configuration
            )
            let receipt = try await Institute.Conversion.Seal(root: root, selection: selection)
                .run()
            print(receipt.canonical)
            let summaryLine =
                "conversion seal: \(receipt.cohort.count) repositories, "
                + "\(receipt.pages.count) pages"
                + ", digest \(receipt.digest)" + "\n"
            Console.Output.error(summaryLine)
        }
    }

    /// `institute conversion check` — re-read and verify a sealed receipt.
    public struct Check: Sendable, Command_Schema.Command.`Protocol` {
        public var receiptPath: Swift.String

        public init(receiptPath: Swift.String = "") { self.receiptPath = receiptPath }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "check", abstract: "Verify a sealed conversion receipt.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.receiptPath,
                    name: .long(.literal("receipt")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Conversion receipt file this check re-reads (issue #83)."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !receiptPath.isEmpty else {
                throw .validationFailed(reason: "conversion check requires --receipt.")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Conversion.Command.root()
            let validated: File.Path
            do throws(File.Path.Error) {
                validated = try File.Path(receiptPath)
            } catch {
                throw .configuration("invalid --receipt path \(receiptPath): \(error)")
            }
            let bytes: [Byte]
            do throws(Either<File.System.Read.Full.Error, Never>) {
                bytes = try File.System.Read.Full.read(from: validated) {
                    (span: Swift.Span<Byte>) in
                    var storage = [Byte]()
                    storage.reserveCapacity(span.count)
                    for index in span.indices {
                        storage.append(span[index])
                    }
                    return storage
                }
            } catch {
                throw .configuration("cannot read --receipt \(receiptPath): \(error)")
            }
            let receipt: Institute.Conversion.Receipt
            do throws(JSON.Error) {
                receipt = try .init(
                    jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
                )
            } catch {
                throw .configuration("cannot decode --receipt \(receiptPath): \(error)")
            }
            let diagnostics = Institute.Conversion.Check.diagnostics(for: receipt, root: root)
            guard diagnostics.isEmpty else {
                throw .configuration(diagnostics.joined(separator: "\n"))
            }
            print("conversion: current — \(receipt.cohort.count) repositories consistent")
        }
    }
}

extension Institute.Conversion {
    /// `institute conversion` — the conversion verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case seal(Seal)
        case check(Check)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "conversion", abstract: "Seal and verify the conversion receipt.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "seal",
                        help: .init(abstract: "Seal the conversion receipt."),
                        initial: { .init() },
                        map: Self.seal
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "check",
                        help: .init(abstract: "Verify a sealed conversion receipt."),
                        initial: { .init() },
                        map: Self.check
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .seal(var command):
                try await command.run()
                self = .seal(command)
            case .check(var command):
                try await command.run()
                self = .check(command)
            }
        }
    }
}
