import File_System
import Institute_Model
import Institute_Source_Policy
import Institute_Source_Workspace
import Source_Measurement
import Source_Profile
import Source_Repair
import Synchronization
import Testing

@testable import Institute_Source

/// `Institute.Source.Application.repair` over a package on disk, with a
/// stand-in for swift-format: its `lint` reports one finding for each file
/// whose text holds `BAD` or `STUCK`, and its `format` turns `BAD` into
/// `GOOD` and leaves `STUCK` alone, so a file holding `STUCK` still has a
/// finding after its rewrite.
/// A package on disk with a preparation whose tools are stand-in files.
private struct Package {
    let root: Swift.String
    let subject: Source.Subject
    let preparation: Institute.Source.Preparation

    init(files: [Swift.String: Swift.String]) throws(Institute.Error) {
        root = MainFixtureFiles.resolvedTemporaryPath("repair-\(MainFixtureFiles.uniqueName())")
        let directory = MainFixtureFiles.join(root, ".source")
        #expect(MainFixtureFiles.makeDirectory(MainFixtureFiles.join(root, "Sources")))
        #expect(MainFixtureFiles.makeDirectory(directory))
        func write(_ text: Swift.String, _ path: Swift.String) {
            #expect(MainFixtureFiles.createFile(path, contents: Swift.Array(text.utf8)))
        }
        write("// swift-tools-version: 6.4\n", MainFixtureFiles.join(root, "Package.swift"))
        for (path, text) in files { write(text, MainFixtureFiles.join(root, path)) }
        subject = try Institute.Source.Workspace.subject(
            identity: "swift-atoms/swift-example@\(Swift.String(repeating: "a", count: 40))",
            root: root,
            paths: ["Package.swift"] + files.keys
        )
        let policy = Institute.Source.Policy.current
        write(policy.swiftFormat.contents, MainFixtureFiles.join(directory, ".swift-format"))
        write(policy.swiftFormatRepair.contents, MainFixtureFiles.join(directory, ".swift-format-repair"))
        write(policy.swiftLint.contents, MainFixtureFiles.join(directory, ".swiftlint.yml"))
        func tool(_ name: Swift.String) throws(Institute.Error) -> (path: Swift.String, digest: Source.Profile.Digest) {
            let path = MainFixtureFiles.join(directory, name)
            write("stand-in for \(name)", path)
            return (path, try Institute.Source.Application.digest(file: path))
        }
        let format = try tool("swift-format")
        let swiftLint = try tool("swiftlint")
        let linter = try tool("swift-linter")
        let prepared: File.Directory
        do throws(File.Path.Error) {
            prepared = try File.Directory(validating: directory)
        } catch {
            throw .configuration("invalid fixture directory \(directory)")
        }
        preparation = .init(
            policyRevision: policy.revision,
            binding: .package(subject.binding),
            swiftFormatExecutable: format.path,
            swiftFormatTool: format.digest,
            swiftLintExecutable: swiftLint.path,
            swiftLint: .init(origin: .local, digest: swiftLint.digest),
            linterExecutable: linter.path,
            linter: .init(origin: .local, digest: linter.digest),
            directory: prepared,
            profiles: [:],
            verifiedProfiles: []
        )
    }

    func text(_ path: Swift.String) -> Swift.String {
        Swift.String(
            decoding: MainFixtureFiles.readBytesIfPresent(MainFixtureFiles.join(root, path)) ?? [],
            as: Swift.UTF8.self
        )
    }

    func remove() { MainFixtureFiles.discard(root) }
}

/// The stand-in swift-format, and the commands it was run with.
private final class Format: Sendable {
    let commands = Mutex<[[Swift.String]]>([])

    var process: Source.Engine.Process {
        .init { [self] _, arguments, _, _ in
            commands.withLock { $0.append(arguments) }
            switch arguments.first {
            case "lint":
                var diagnostics = ""
                for file in arguments.dropFirst(4) {
                    guard let bytes = MainFixtureFiles.readBytesIfPresent(file) else {
                        return .init(status: 2, output: "", diagnostics: "cannot read \(file)")
                    }
                    let text = Swift.String(decoding: bytes, as: Swift.UTF8.self)
                    if text.contains("BAD") || text.contains("STUCK") {
                        diagnostics += "\(file):1:1: error: [Spacing] remove 1 space\n"
                    }
                }
                return .init(status: diagnostics.isEmpty ? 0 : 1, output: "", diagnostics: diagnostics)

            case "format":
                guard let file = arguments.last, let bytes = MainFixtureFiles.readBytesIfPresent(file) else {
                    return .init(status: 2, output: "", diagnostics: "cannot read the file")
                }
                return .init(
                    status: 0,
                    output: MainFixtureFiles.replacingAll(
                        "BAD",
                        with: "GOOD",
                        in: Swift.String(decoding: bytes, as: Swift.UTF8.self)
                    ),
                    diagnostics: ""
                )

            default:
                return .init(status: 64, output: "", diagnostics: "unexpected command")
            }
        }
    }
}

@Test
func `repair rewrites each file whose rewrite leaves no finding, and only those`() async throws {
    let package = try Package(files: [
        "Sources/A.swift": "let a = \"BAD\"\n",
        "Sources/B.swift": "let b = 1\n",
        "Sources/C.swift": "let c = \"STUCK BAD\"\n",
    ])
    let format = Format()

    let repaired = try await Institute.Source.Application(process: format.process).repair(
        subject: package.subject,
        bundle: .primitives,
        preparation: package.preparation
    )

    #expect(repaired.rewritten == ["Sources/A.swift"])
    #expect(
        repaired.declined == [
            .init(
                file: "Sources/C.swift",
                reason: "its rewrite still has findings under the repair configuration"
            )
        ]
    )
    #expect(package.text("Sources/A.swift") == "let a = \"GOOD\"\n")
    #expect(package.text("Sources/B.swift") == "let b = 1\n")
    #expect(package.text("Sources/C.swift") == "let c = \"STUCK BAD\"\n")
    #expect(!MainFixtureFiles.exists(MainFixtureFiles.join(package.root, ".source/repair")))
    let configurations = Set(
        try format.commands.withLock { $0 }.map { try File.Path($0[$0.count > 3 && $0[0] == "lint" ? 3 : 2]) }
    )
    #expect(configurations == [try File.Path(MainFixtureFiles.join(package.root, ".source/.swift-format-repair"))])
    package.remove()
}

@Test
func `repair of a package with nothing to repair runs no rewrite and changes nothing`() async throws {
    let package = try Package(files: ["Sources/B.swift": "let b = 1\n"])
    let format = Format()

    let repaired = try await Institute.Source.Application(process: format.process).repair(
        subject: package.subject,
        bundle: .primitives,
        preparation: package.preparation
    )

    #expect(repaired == .init(rewritten: [], declined: []))
    #expect(format.commands.withLock { $0 }.map(\.first) == ["lint"])
    #expect(package.text("Sources/B.swift") == "let b = 1\n")
    package.remove()
}

@Test
func `repair leaves every file alone when no rewrite clears its findings`() async throws {
    let package = try Package(files: ["Sources/C.swift": "let c = \"STUCK\"\n"])

    let repaired = try await Institute.Source.Application(process: Format().process).repair(
        subject: package.subject,
        bundle: .primitives,
        preparation: package.preparation
    )

    #expect(repaired.rewritten.isEmpty)
    #expect(package.text("Sources/C.swift") == "let c = \"STUCK\"\n")
    package.remove()
}

@Test
func `repair refuses a preparation made for another subject`() async throws {
    let package = try Package(files: ["Sources/A.swift": "let a = \"BAD\"\n"])
    let other = try Package(files: ["Sources/A.swift": "let a = \"BAD\"\n", "Sources/B.swift": "let b = 1\n"])

    await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Application(process: Format().process).repair(
            subject: package.subject,
            bundle: .primitives,
            preparation: other.preparation
        )
    }
    #expect(package.text("Sources/A.swift") == "let a = \"BAD\"\n")
    package.remove()
    other.remove()
}

@Test
func `repair refuses a preparation whose tool changed since it was made`() async throws {
    let package = try Package(files: ["Sources/A.swift": "let a = \"BAD\"\n"])
    #expect(
        MainFixtureFiles.createFile(package.preparation.swiftFormatExecutable, contents: Swift.Array("another tool".utf8))
    )

    await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Application(process: Format().process).repair(
            subject: package.subject,
            bundle: .primitives,
            preparation: package.preparation
        )
    }
    #expect(package.text("Sources/A.swift") == "let a = \"BAD\"\n")
    package.remove()
}

@Test
func `a measurement of the staged copy is reported at the subject's own paths`() throws {
    let package = try Package(files: ["Sources/A.swift": "let a = 1\n"])
    let rule = Source.Rule.ID(engine: .init("swift-format"), token: "format")
    let scratch = "/scratch/repair"
    let staged = scratch + "/Sources/A.swift"
    let measurement = Source.Measurement(
        engine: rule.engine,
        subject: .init(identity: package.subject.identity, root: scratch, artifacts: package.subject.artifacts),
        activeRules: [rule],
        applicableRules: [rule],
        files: [staged],
        observations: [.init(file: staged, rule: rule, applicable: true, coverage: .measured)],
        repairs: [.init(file: staged, rule: rule, disposition: .refused(.init(code: "unavailable", detail: staged)))],
        verdict: .findings([
            .init(
                rule: rule,
                diagnostic: .init(
                    location: .init(fileID: staged, filePath: staged, line: 3, column: 5),
                    severity: .error,
                    identifier: "Spacing",
                    message: "remove 1 space"
                ),
                repair: .unavailable(.init(code: "unavailable", detail: staged))
            )
        ])
    )

    let relocated = Institute.Source.Application.relocated(measurement, from: scratch, to: package.subject)

    let own = package.root + "/Sources/A.swift"
    #expect(relocated.subject == package.subject)
    #expect(relocated.files == [own])
    #expect(relocated.observations.map(\.file) == [own])
    #expect(relocated.repairs.map(\.file) == [own])
    guard case .findings(let findings) = relocated.verdict, let finding = findings.first else {
        Issue.record("the relocated measurement lost its finding")
        return
    }
    #expect(finding.diagnostic.location.filePath == own)
    #expect(finding.diagnostic.location.fileID == own)
    #expect(finding.diagnostic.message == "remove 1 space")
    #expect(finding.repair == .unavailable(.init(code: "unavailable", detail: own)))
    package.remove()
}
