import Byte
public import Command
public import Command_Schema
import Console
import Environment
import File_System
import Git_Foundation
public import Institute_Instruments
public import Institute_Model
import JSON
import Process

extension Institute.Verification.Command {
    /// `institute verification seal` — run and seal one verification.
    public struct Seal: Sendable, Command_Schema.Command.`Protocol` {
        public var packagePath: Swift.String
        public var receiptPath: Swift.String
        public var claimedHead: Swift.String
        public var defaultBranch: Swift.String
        public var verificationVisibility: Swift.String
        public var verificationLayer: Swift.String
        public var inventoryDigest: Swift.String
        public var inventoryDigestCause: Swift.String
        public var workspaceRevision: Swift.String
        public var policyRevision: Swift.String
        public var requestedOperations: [Swift.String]
        public var requiredOperations: [Swift.String]
        public var platformSupport: [Swift.String]
        public var fresh: Bool
        public var jobs: Swift.Int?
        public var arguments: [Swift.String]

        public init(
            packagePath: Swift.String = "",
            receiptPath: Swift.String = "",
            claimedHead: Swift.String = "",
            defaultBranch: Swift.String = "",
            verificationVisibility: Swift.String = "",
            verificationLayer: Swift.String = "",
            inventoryDigest: Swift.String = "",
            inventoryDigestCause: Swift.String = "",
            workspaceRevision: Swift.String = "",
            policyRevision: Swift.String = "",
            requestedOperations: [Swift.String] = [],
            requiredOperations: [Swift.String] = [],
            platformSupport: [Swift.String] = [],
            fresh: Bool = false,
            jobs: Swift.Int? = nil,
            arguments: [Swift.String] = []
        ) {
            self.packagePath = packagePath
            self.receiptPath = receiptPath
            self.claimedHead = claimedHead
            self.defaultBranch = defaultBranch
            self.verificationVisibility = verificationVisibility
            self.verificationLayer = verificationLayer
            self.inventoryDigest = inventoryDigest
            self.inventoryDigestCause = inventoryDigestCause
            self.workspaceRevision = workspaceRevision
            self.policyRevision = policyRevision
            self.requestedOperations = requestedOperations
            self.requiredOperations = requiredOperations
            self.platformSupport = platformSupport
            self.fresh = fresh
            self.jobs = jobs
            self.arguments = arguments
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "seal", abstract: "Run and seal one package verification receipt.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.packagePath,
                    name: .long(.literal("package-path")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Package root the verification runs from (defaults to PWD)."
                    )
                )
                Command_Schema.Command.Option(
                    \.receiptPath,
                    name: .long(.literal("receipt")),
                    placeholder: "path",
                    help: .init(
                        abstract: "The seal's newly created output path (#253)."
                    )
                )
                Command_Schema.Command.Option(
                    \.claimedHead,
                    name: .long(.literal("claimed-head")),
                    placeholder: "sha",
                    help: .init(
                        abstract: "The exact head revision this verification claims."
                    )
                )
                Command_Schema.Command.Option(
                    \.defaultBranch,
                    name: .long(.literal("default-branch")),
                    placeholder: "branch",
                    help: .init(
                        abstract: "The subject's default branch."
                    )
                )
                Command_Schema.Command.Option(
                    \.verificationVisibility,
                    name: .long(.literal("visibility")),
                    placeholder: "public|private|unmeasured",
                    help: .init(
                        abstract: "The subject's recorded visibility."
                    )
                )
                Command_Schema.Command.Option(
                    \.verificationLayer,
                    name: .long(.literal("layer")),
                    placeholder: "atoms|molecules|standards|compositions",
                    help: .init(
                        abstract: "The subject's inventory layer."
                    )
                )
                Command_Schema.Command.Option(
                    \.inventoryDigest,
                    name: .long(.literal("inventory-digest")),
                    placeholder: "digest|unmeasured",
                    help: .init(
                        abstract: "The exact inventory digest, or unmeasured with a cause."
                    )
                )
                Command_Schema.Command.Option(
                    \.inventoryDigestCause,
                    name: .long(.literal("inventory-digest-cause")),
                    placeholder: "cause",
                    help: .init(
                        abstract: "Why the inventory digest is unmeasured, when it is."
                    )
                )
                Command_Schema.Command.Option(
                    \.workspaceRevision,
                    name: .long(.literal("workspace-revision")),
                    placeholder: "sha",
                    help: .init(
                        abstract:
                            "The Institute source/executable revision performing this run "
                    )
                )
                Command_Schema.Command.Option(
                    \.policyRevision,
                    name: .long(.literal("policy-revision")),
                    placeholder: "sha",
                    help: .init(
                        abstract: "The policy revision this verification runs under."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.requestedOperations,
                    name: .long(.literal("step")),
                    placeholder: "build|test|nested-tests|lint",
                    help: .init(
                        abstract: "One requested verification operation (repeatable)."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.requiredOperations,
                    name: .long(.literal("required-step")),
                    placeholder: "build|test|nested-tests|lint",
                    help: .init(
                        abstract: "One required verification operation (repeatable)."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.platformSupport,
                    name: .long(.literal("platform-support")),
                    placeholder: "name",
                    help: .init(
                        abstract:
                            "One declared supported-platform name, carried verbatim "
                            + "(repeatable)."
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
                        abstract: "Cap compile jobs the coordinator gives SwiftPM."
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

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !receiptPath.isEmpty else {
                throw .validationFailed(
                    reason: "verification requires --receipt (seal's output path)."
                )
            }
            guard !claimedHead.isEmpty else {
                throw .validationFailed(reason: "verification seal requires --claimed-head.")
            }
            guard !defaultBranch.isEmpty else {
                throw .validationFailed(reason: "verification seal requires --default-branch.")
            }
            guard Institute.Verification.Visibility(rawValue: verificationVisibility) != nil
            else {
                throw .validationFailed(
                    reason:
                        "verification seal requires --visibility public, private, or unmeasured."
                )
            }
            guard Institute.Layer(rawValue: verificationLayer) != nil else {
                throw .validationFailed(
                    reason:
                        "verification seal requires --layer atoms, molecules, standards, "
                        + "or compositions."
                )
            }
            guard !inventoryDigest.isEmpty else {
                throw .validationFailed(
                    reason: "verification seal requires --inventory-digest."
                )
            }
            // The digest and its cause are validated together, here, so
            // an unmeasured digest without a cause is refused before a
            // run starts rather than sealed and discovered downstream.
            do throws(Institute.Verification.Inventory.Digest.Error) {
                _ = try Institute.Verification.Inventory.Digest(
                    token: inventoryDigest,
                    cause: inventoryDigestCause.isEmpty ? nil : inventoryDigestCause
                )
            } catch {
                throw .validationFailed(reason: "verification seal: \(error).")
            }
            guard !workspaceRevision.isEmpty else {
                throw .validationFailed(
                    reason: "verification seal requires --workspace-revision."
                )
            }
            guard !policyRevision.isEmpty else {
                throw .validationFailed(reason: "verification seal requires --policy-revision.")
            }
            for value in requestedOperations + requiredOperations {
                guard Institute.Verification.Operation.Kind(rawValue: value) != nil else {
                    throw .validationFailed(
                        reason:
                            "\(value) is not build, test, nested-tests, or lint "
                            + "(--step/--required-step)."
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            guard let working = Environment.read("PWD") else {
                throw .configuration("PWD is not available")
            }
            let subjectPath = packagePath.isEmpty ? working : packagePath
            let remote: Swift.String
            do throws(Git.Client.Error) {
                remote = try Git.Client().remote("origin", at: subjectPath)
            } catch {
                throw .process(
                    "cannot read the subject's origin remote at \(subjectPath): \(error)"
                )
            }
            guard let coordinate = Institute.Repository.Key(url: remote) else {
                throw .configuration(
                    "origin remote \(remote) is not a canonical https://github.com/owner/name.git URL"
                )
            }
            // `validate()` already refused every invalid combination;
            // this reconstructs the typed value it validated.
            let verificationInventoryDigest: Institute.Verification.Inventory.Digest
            do throws(Institute.Verification.Inventory.Digest.Error) {
                verificationInventoryDigest = try .init(
                    token: inventoryDigest,
                    cause: inventoryDigestCause.isEmpty ? nil : inventoryDigestCause
                )
            } catch {
                throw .configuration("verification seal: \(error)")
            }
            let requested =
                requestedOperations.isEmpty
                ? [Institute.Verification.Operation.Kind.build, .test, .lint]
                : requestedOperations.compactMap(
                    Institute.Verification.Operation.Kind.init(rawValue:)
                )
            let required =
                requiredOperations.isEmpty
                ? requested
                : requiredOperations.compactMap(
                    Institute.Verification.Operation.Kind.init(rawValue:)
                )

            // `validate()` already refused an unrecognised visibility or layer.
            guard
                let visibility = Institute.Verification.Visibility(rawValue: verificationVisibility),
                let layer = Institute.Layer(rawValue: verificationLayer)
            else {
                preconditionFailure("validate() admits only known visibility and layer values")
            }
            let run = Institute.Verification.Run(
                packagePath: subjectPath,
                claimedHead: claimedHead,
                coordinate: coordinate,
                visibility: visibility,
                defaultBranch: defaultBranch,
                layer: layer,
                inventoryDigest: verificationInventoryDigest,
                workspaceRevision: workspaceRevision,
                policyRevision: policyRevision,
                requestedOperations: requested,
                requiredOperations: required,
                platformSupport: platformSupport,
                fresh: fresh,
                jobs: jobs,
                arguments: arguments
            )
            let receipt: Institute.Verification.Receipt
            do throws(Institute.Verification.Error) {
                receipt = try await run.run()
            } catch {
                throw .configuration("verification seal: \(error)")
            }

            let outputPath: File.Path
            do throws(File.Path.Error) {
                outputPath = try File.Path(receiptPath)
            } catch {
                throw .configuration("invalid --receipt path \(receiptPath): \(error)")
            }
            guard !File(outputPath).stat.exists else {
                throw .configuration(
                    "--receipt \(receiptPath) already exists; verification seal writes only a "
                        + "newly created output path"
                )
            }
            let outputFile = File(outputPath)
            // Untyped catch, deliberately: the async `atomic(_:options:)`
            // overload throws `Either<Kernel.Thread.Pool.Error,
            // File.System.Write.Atomic.Error>`, whose first member this
            // file has no reason to name or depend on directly — this
            // call site only needs "did the write succeed," which an
            // untyped `catch` reports exactly as well as spelling out
            // the union would.
            do {
                try await outputFile.write.atomic(receipt.canonical)
            } catch {
                throw .configuration("cannot write --receipt \(receiptPath): \(error)")
            }
            let summaryLine =
                "verification seal: \(receipt.subject.coordinate.identity) "
                + "\(receipt.verdict.fails ? "unverified" : "verified"), "
                + "\(receipt.operations.count) operation(s)"
                + ", digest \(receipt.digest)" + "\n"
            Console.Output.error(summaryLine)
            Process.Exit.normal(receipt.verdict.fails ? 1 : 0)
        }
    }

    /// `institute verification check` — re-read and verify one receipt.
    public struct Check: Sendable, Command_Schema.Command.`Protocol` {
        public var receiptPath: Swift.String

        public init(receiptPath: Swift.String = "") { self.receiptPath = receiptPath }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "check", abstract: "Verify a sealed verification receipt.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.receiptPath,
                    name: .long(.literal("receipt")),
                    placeholder: "path",
                    help: .init(
                        abstract: "The receipt file this check re-reads (#253)."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !receiptPath.isEmpty else {
                throw .validationFailed(
                    reason: "verification requires --receipt (check's input path)."
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let inputPath: File.Path
            do throws(File.Path.Error) {
                inputPath = try File.Path(receiptPath)
            } catch {
                throw .configuration("invalid --receipt path \(receiptPath): \(error)")
            }
            let bytes: [Byte]
            do throws(Either<File.System.Read.Full.Error, Never>) {
                bytes = try File.System.Read.Full.read(from: inputPath) {
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
            let receipt: Institute.Verification.Receipt
            do throws(JSON.Error) {
                receipt = try .init(
                    jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
                )
            } catch {
                throw .configuration("cannot decode --receipt \(receiptPath): \(error)")
            }
            let diagnostics = Institute.Verification.Check.diagnostics(for: receipt)
            guard diagnostics.isEmpty else {
                throw .configuration(diagnostics.joined(separator: "\n"))
            }
            print(
                "verification: current — \(receipt.subject.coordinate.identity) consistent"
                    + ", digest \(receipt.digest)"
            )
        }
    }
}

extension Institute.Verification {
    /// `institute verification` — the verification verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case seal(Seal)
        case check(Check)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "verification", abstract: "Seal and verify verification receipts.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "seal",
                        help: .init(abstract: "Run and seal one verification receipt."),
                        initial: { .init() },
                        map: Self.seal
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "check",
                        help: .init(abstract: "Verify a sealed verification receipt."),
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
