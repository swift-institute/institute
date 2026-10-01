import Foundation

/// An owned local Git workspace the emitted identity script runs against:
/// no network, no remote action, removed by the caller.
struct AnchorShellFixture {
    let workspace: Swift.String

    init() throws {
        workspace = FileManager.default.temporaryDirectory
            .appending(path: "anchor-shell-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(
            atPath: workspace,
            withIntermediateDirectories: true
        )
    }

    func remove() { try? FileManager.default.removeItem(atPath: workspace) }

    /// Creates a one-commit repository at `checkout` (relative to the
    /// workspace) holding `Tools/institute-ci/marker` and returns its
    /// commit, root tree and `Tools/institute-ci` subtree object names.
    func repository(
        at checkout: Swift.String
    ) throws -> (commit: Swift.String, tree: Swift.String, subtree: Swift.String) {
        let directory = workspace + "/" + checkout
        try FileManager.default.createDirectory(
            atPath: directory + "/Tools/institute-ci",
            withIntermediateDirectories: true
        )
        try "marker\n".write(
            toFile: directory + "/Tools/institute-ci/marker",
            atomically: true,
            encoding: .utf8
        )
        for arguments in [
            ["init", "-q"],
            ["add", "-A"],
            [
                "-c", "user.name=fixture", "-c", "user.email=fixture@invalid",
                "-c", "commit.gpgsign=false", "commit", "-q", "-m", "fixture",
            ],
        ] {
            _ = try Self.run("/usr/bin/env", ["git"] + arguments, in: directory, environment: [:])
        }
        func parse(_ revision: Swift.String) throws -> Swift.String {
            try Self.run("/usr/bin/env", ["git", "rev-parse", revision], in: directory, environment: [:])
                .standardOutput
                .split(separator: "\n").first.map(Swift.String.init) ?? ""
        }
        return (try parse("HEAD"), try parse("HEAD^{tree}"), try parse("HEAD:Tools/institute-ci"))
    }

    /// Runs `script` with bash in the workspace, as a workflow step would,
    /// and returns its exit status, standard output and `GITHUB_OUTPUT`.
    func execute(
        _ script: Swift.String
    ) throws -> (status: Swift.Int32, standardOutput: Swift.String, output: Swift.String) {
        let output = workspace + "/github-output"
        FileManager.default.createFile(atPath: output, contents: Data())
        let result = try Self.run(
            "/usr/bin/env",
            ["bash", "-c", script],
            in: workspace,
            environment: ["GITHUB_WORKSPACE": workspace, "GITHUB_OUTPUT": output]
        )
        return (
            result.status,
            result.standardOutput,
            try Swift.String(contentsOfFile: output, encoding: .utf8)
        )
    }

    func exists(_ relative: Swift.String) -> Swift.Bool {
        FileManager.default.fileExists(atPath: workspace + "/" + relative)
    }

    private static func run(
        _ executable: Swift.String,
        _ arguments: [Swift.String],
        in directory: Swift.String,
        environment: [Swift.String: Swift.String]
    ) throws -> (status: Swift.Int32, standardOutput: Swift.String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, Swift.String(decoding: data, as: UTF8.self))
    }
}
