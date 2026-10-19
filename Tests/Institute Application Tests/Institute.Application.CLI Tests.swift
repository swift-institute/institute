import Command
import Institute_Build_Coordinator
import Institute_Certification_Application
import Institute_Coherence_Application
import Institute_Composition_Application
import Institute_Context_Application
import Institute_Conversion_Application
import Institute_Dependency
import Institute_Dependency_Application
import Institute_Development
import Institute_Doctor_Application
import Institute_GitHub_Application
import Institute_Inventory_Application
import Institute_Model
import Institute_Navigation_Application
import Institute_Package_Application
import Institute_Verification_Application
import Institute_Workspace_Application
import Testing

@testable import Institute_Application

/// Parses one argv through the typed router, exactly as `main.swift` does.
private func parse(
    _ argv: [Swift.String]
) throws -> Institute.Application.CLI {
    try Command.parse(Institute.Application.CLI.self, from: argv, initial: .sync(.init()))
}

extension Institute.Application.CLI {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Application.CLI.Test.Unit {
    @Test
    func `workspace materialize selects the local publication operation`() throws {
        let command = try parse(["workspace", "materialize", "--jobs", "16"])

        guard case .workspace(.materialize(let materialize)) = command else {
            Issue.record("expected workspace materialize, got \(command)")
            return
        }
        #expect(materialize.jobs == 16)
    }

    @Test
    func `workspace scheme selects an existing workspace`() throws {
        let command = try parse([
            "workspace", "scheme", "--workspace-path", "institute control.xcworkspace",
            "--jobs", "8",
        ])

        guard case .workspace(.scheme(let scheme)) = command else {
            Issue.record("expected workspace scheme, got \(command)")
            return
        }
        #expect(scheme.workspacePath == "institute control.xcworkspace")
        #expect(scheme.jobs == 8)
    }

    @Test
    func `install selects the command bootstrap`() throws {
        let command = try parse(["install"])

        guard case .install = command else {
            Issue.record("expected install, got \(command)")
            return
        }
    }

    @Test
    func `sync selects mutating execution`() throws {
        let command = try parse(["sync"])

        guard case .sync(let sync) = command else {
            Issue.record("expected sync, got \(command)")
            return
        }
        #expect(!sync.dry)
    }

    @Test
    func `sync dry run selects nonmutating execution`() throws {
        let command = try parse(["sync", "--dry-run"])

        guard case .sync(let sync) = command else {
            Issue.record("expected sync, got \(command)")
            return
        }
        #expect(sync.dry)
    }

    @Test
    func `doctor selects diagnostic execution`() throws {
        let command = try parse(["doctor"])

        guard case .doctor(let doctor) = command else {
            Issue.record("expected doctor, got \(command)")
            return
        }
        #expect(!doctor.institute)
    }

    @Test
    func `doctor institute selects the institute-internal checks`() throws {
        let command = try parse(["doctor", "--institute"])

        guard case .doctor(let doctor) = command else {
            Issue.record("expected doctor, got \(command)")
            return
        }
        #expect(doctor.institute)
    }

    @Test
    func `inventory selects the read-only register`() throws {
        let command = try parse(["inventory"])

        guard case .inventory(.register) = command else {
            Issue.record("expected inventory register, got \(command)")
            return
        }
    }

    @Test
    func `inventory regenerate selects mutating execution`() throws {
        let command = try parse(["inventory", "regenerate"])

        guard case .inventory(.regenerate(let regenerate)) = command else {
            Issue.record("expected inventory regenerate, got \(command)")
            return
        }
        #expect(!regenerate.dry)
    }

    @Test
    func `inventory regenerate dry run selects nonmutating planning`() throws {
        let command = try parse(["inventory", "regenerate", "--dry-run"])

        guard case .inventory(.regenerate(let regenerate)) = command else {
            Issue.record("expected inventory regenerate, got \(command)")
            return
        }
        #expect(regenerate.dry)
    }

    @Test
    func `inventory pages selects the read-only page enumeration`() throws {
        let command = try parse(["inventory", "pages"])

        guard case .inventory(.pages) = command else {
            Issue.record("expected inventory pages, got \(command)")
            return
        }
    }

    @Test
    func `inventory pages rejects dry run because enumeration is already read-only`() {
        #expect(throws: Command.Error.self) {
            try parse(["inventory", "pages", "--dry-run"])
        }
    }

    @Test
    func `inventory effective parses its scope and output path`() throws {
        let command = try parse([
            "inventory", "effective",
            "--inventory-scope", "effective",
            "--inventory-output", "/tmp/effective.json",
        ])

        guard case .inventory(.effective(let effective)) = command else {
            Issue.record("expected inventory effective, got \(command)")
            return
        }
        #expect(effective.inventoryScope == "effective")
        #expect(effective.inventoryOutput == "/tmp/effective.json")
    }

    @Test
    func `inventory effective parses the public-only scope`() throws {
        let command = try parse([
            "inventory", "effective",
            "--inventory-scope", "public",
            "--inventory-output", "/tmp/effective.json",
        ])

        guard case .inventory(.effective(let effective)) = command else {
            Issue.record("expected inventory effective, got \(command)")
            return
        }
        #expect(effective.inventoryScope == "public")
    }

    @Test
    func `inventory effective rejects dry run`() {
        #expect(throws: Command.Error.self) {
            try parse([
                "inventory", "effective",
                "--inventory-scope", "public",
                "--inventory-output", "/tmp/effective.json",
                "--dry-run",
            ])
        }
    }

    @Test
    func `inventory register rejects the effective-only report options`() {
        #expect(throws: Command.Error.self) {
            try parse(["inventory", "--inventory-scope", "public"])
        }
    }

    @Test
    func `dependencies parses deterministic output and policy exception inputs`() throws {
        let command = try parse([
            "dependencies",
            "--format", "json",
            "--sanctioned-exception", "apple/swift-crypto",
            "--sanctioned-exception", "swiftlang/swift-syntax",
        ])

        guard case .dependencies(let dependencies) = command else {
            Issue.record("expected dependencies, got \(command)")
            return
        }
        #expect(dependencies.output == .json)
        #expect(
            dependencies.sanctionedExceptions == [
                "apple/swift-crypto",
                "swiftlang/swift-syntax",
            ]
        )
    }

    @Test
    func `context install parses`() throws {
        let command = try parse(["context", "install"])
        guard case .context(.install) = command else {
            Issue.record("expected context install, got \(command)")
            return
        }
    }

    @Test
    func `context check parses`() throws {
        let command = try parse(["context", "check"])
        guard case .context(.check) = command else {
            Issue.record("expected context check, got \(command)")
            return
        }
    }

    @Test
    func `context packet parses its bounded current Issue contract`() throws {
        let command = try parse([
            "context", "packet",
            "--issue", "swift-institute/institute-application#100",
            "--format", "json",
            "--max-bytes", "512",
            "--include-comment",
            "https://api.github.com/repos/swift-institute/institute-application/issues/comments/1",
        ])

        guard case .context(.packet(let packet)) = command else {
            Issue.record("expected context packet, got \(command)")
            return
        }
        #expect(packet.issue == "swift-institute/institute-application#100")
        #expect(packet.output == "json")
        #expect(packet.maxBytes == 512)
        #expect(packet.includedComments.count == 1)
    }

    @Test(arguments: ["install", "check", "serve"])
    func `navigation parses its operation`(argument: Swift.String) throws {
        let argv: [Swift.String] =
            argument == "serve"
            ? ["navigation", argument]
            : ["navigation", argument, "--workspace-path", "/tmp/Institute"]
        let command = try parse(argv)

        guard case .navigation(let navigation) = command else {
            Issue.record("expected navigation, got \(command)")
            return
        }
        switch (argument, navigation) {
        case ("install", .install(let install)):
            #expect(install.workspacePath == "/tmp/Institute")

        case ("check", .check(let check)):
            #expect(check.workspacePath == "/tmp/Institute")

        case ("serve", .serve):
            break

        default:
            Issue.record("navigation \(argument) parsed as \(navigation)")
        }
    }

    @Test(arguments: ["build", "test"])
    func `package parses its coordinated operations`(argument: Swift.String) throws {
        let command = try parse(["package", argument, "--package-path", "/tmp/example"])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package \(argument), got \(command)")
            return
        }
        #expect(execute.action == (argument == "build" ? .build : .test))
        #expect(execute.packagePath == "/tmp/example")
    }

    @Test(arguments: [
        ("resolve", Institute.Build.Action.resolve),
        ("dump-package", Institute.Build.Action.dumpPackage),
    ])
    func `package parses its forwarded operations`(
        argument: Swift.String,
        expected: Institute.Build.Action
    ) throws {
        let command = try parse(["package", argument, "--package-path", "/tmp/example"])

        guard case .package(.forward(let forward)) = command else {
            Issue.record("expected package \(argument), got \(command)")
            return
        }
        #expect(forward.action == expected)
        #expect(forward.packagePath == "/tmp/example")
    }

    @Test
    func `fresh package test parses`() throws {
        let command = try parse(["package", "test", "--fresh"])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package test, got \(command)")
            return
        }
        #expect(execute.fresh)
    }

    @Test(arguments: ["build", "test"])
    func `jobs caps compile concurrency on package build or test`(
        mode: Swift.String
    ) throws {
        let command = try parse(["package", mode, "--jobs", "2"])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package \(mode), got \(command)")
            return
        }
        #expect(execute.jobs == 2)
    }

    @Test
    func `jobs is nil by default, so the coordinator keeps choosing the machine's core count`()
        throws
    {
        let command = try parse(["package", "build"])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package build, got \(command)")
            return
        }
        #expect(execute.jobs == nil)
    }

    @Test
    func `the parsed jobs cap reaches the coordinator constructor unchanged`() throws {
        // Plumbing only: `run()` passes `jobs` straight into
        // `Institute.Build.Coordinator(jobs:)` without transforming it, so asserting
        // the constructor echoes the parsed value is the whole contract —
        // `Institute.Build.Coordinator` and `Institute.Build.Action` already prove the rest of
        // the chain (jobs reaching SwiftPM's `-j`) independently.
        let command = try parse(["package", "test", "--jobs", "5"])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package test, got \(command)")
            return
        }
        #expect(Institute.Build.Coordinator(jobs: execute.jobs).jobs == 5)
    }

    @Test
    func `package forwards repeated SwiftPM arguments`() throws {
        let command = try parse([
            "package", "test",
            "--argument=--filter",
            "--argument", "Performance",
        ])

        guard case .package(.execute(let execute)) = command else {
            Issue.record("expected package test, got \(command)")
            return
        }
        #expect(execute.arguments == ["--filter", "Performance"])
    }
}

extension Institute.Application.CLI.Test.`Edge Case` {
    @Test
    func `install takes no mode`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["install", "check"])
        }
    }

    @Test
    func `install rejects package arguments`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["install", "--package-path", "Application"])
        }
    }

    @Test
    func `doctor rejects dry run`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["doctor", "--dry-run"])
        }
    }

    @Test
    func `inventory rejects dry run because the register is already read-only`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["inventory", "--dry-run"])
        }
    }

    @Test
    func `inventory rejects a mutating mode that is not regeneration`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["inventory", "update"])
        }
    }

    @Test
    func `dependencies rejects malformed or duplicate exception inputs`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["dependencies", "--sanctioned-exception", "not-an-identity"])
        }
        #expect(throws: Command.Error.self) {
            _ = try parse([
                "dependencies",
                "--sanctioned-exception", "apple/swift-crypto",
                "--sanctioned-exception", "apple/swift-crypto",
            ])
        }
    }

    // A dropped `--institute` would print a report indistinguishable from
    // the one that measured the roster. Rejecting it is the point.
    @Test(arguments: [["sync"], ["inventory"], ["package", "build"]])
    func `institute is rejected outside doctor`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try parse(argument + ["--institute"])
        }
    }

    @Test
    func `context requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["context"])
        }
    }

    @Test
    func `context rejects a package operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["context", "build"])
        }
    }

    @Test
    func `navigation requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["navigation"])
        }
    }

    @Test
    func `navigation rejects a package operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["navigation", "build"])
        }
    }

    @Test
    func `non-context operation rejects a context operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["sync", "install"])
        }
    }

    @Test
    func `package requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["package"])
        }
    }

    @Test
    func `package rejects a context operation`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["package", "install"])
        }
    }

    @Test(arguments: [
        ["lint"],
        ["package", "lint"],
        ["package", "check"],
    ])
    func `obsolete lint command surfaces are rejected`(arguments: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try parse(arguments)
        }
    }

    @Test
    func `fresh rejects package resolve`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["package", "resolve", "--fresh"])
        }
    }

    // `Institute.Build.Action.acceptsJobs` covers run too, but the CLI surface stays
    // narrower than the API: build and test are the coordinated-build entry
    // points issue #88 asks for, and widening silently to `run` later is a
    // deliberate choice, not a side effect of this guard's shape.
    @Test(arguments: [
        ["package", "resolve"],
        ["package", "run"],
        ["build"],
        ["sync"],
        ["doctor"],
    ])
    func `jobs is rejected outside package build or test`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try parse(argument + ["--jobs", "2"])
        }
    }
}

extension Institute.Application.CLI.Test.Unit {
    @Test(arguments: ["compose", "restore", "verify"])
    func `composition operations parse consumer and dependency`(
        operation: Swift.String
    ) throws {
        let command = try parse([
            operation, "--consumer", "swift-color", "--dependency", "swift-color-standard",
        ])

        guard case .composition(let composition) = command else {
            Issue.record("expected \(operation), got \(command)")
            return
        }
        let expected: Institute.Composition.Command.Action =
            switch operation {
            case "compose": .compose
            case "restore": .restore
            default: .verify
            }
        #expect(composition.action == expected)
        #expect(composition.consumer == "swift-color")
        #expect(composition.dependency == "swift-color-standard")
    }
}

extension Institute.Application.CLI.Test.`Edge Case` {
    @Test
    func `compose requires consumer`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["compose", "--dependency", "swift-color-standard"])
        }
    }

    @Test
    func `compose requires dependency`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["compose", "--consumer", "swift-color"])
        }
    }

    @Test
    func `sync rejects consumer and dependency`() {
        #expect(throws: Command.Error.self) {
            _ = try parse([
                "sync", "--consumer", "swift-color", "--dependency", "swift-color-standard",
            ])
        }
    }

    @Test
    func `compose rejects dry run`() {
        #expect(throws: Command.Error.self) {
            _ = try parse([
                "compose", "--consumer", "swift-color", "--dependency", "swift-color-standard",
                "--dry-run",
            ])
        }
    }
}

extension Institute.Application.CLI.Test.Unit {
    @Test
    func `build selects the whole selection, not a package`() throws {
        let command = try parse(["build"])

        guard case .build(let build) = command else {
            Issue.record("expected build, got \(command)")
            return
        }
        #expect(!build.fresh)
        #expect(build.arguments.isEmpty)
    }

    @Test
    func `build accepts isolated derived data and forwarded xcodebuild arguments`() throws {
        let command = try parse(["build", "--fresh", "--argument", "CONFIGURATION=Release"])

        guard case .build(let build) = command else {
            Issue.record("expected build, got \(command)")
            return
        }
        #expect(build.fresh)
        #expect(build.arguments == ["CONFIGURATION=Release"])
    }
}

extension Institute.Application.CLI.Test.`Edge Case` {
    @Test
    func `build takes no mode`() {
        // `institute build build` would read as a package operation and is a
        // plausible slip; it must not silently mean the whole selection.
        #expect(throws: Command.Error.self) {
            _ = try parse(["build", "build"])
        }
    }

    @Test
    func `build refuses a package path rather than narrowing to one package`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["build", "--package-path", "/tmp/pkg"])
        }
    }

    @Test
    func `build has no dry run`() {
        // There is nothing to plan: the selection and the scheme are already
        // on disk, and a build that changed nothing would still be a build.
        #expect(throws: Command.Error.self) {
            _ = try parse(["build", "--dry-run"])
        }
    }
}
