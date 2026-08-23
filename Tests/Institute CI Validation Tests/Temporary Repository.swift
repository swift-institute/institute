import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import ContinuousIntegration

@testable import Institute_CI_Validation

/// A throwaway repository-shaped directory a validator can be asked
/// about.
///
/// The fixture corpus under `.github/scripts/tests/fixtures/` is the
/// contract's shared corpus and is **data** — it is read, never written.
/// A control that needs a shape the corpus does not carry (a baseline
/// ledger, a deliberately unpinned reference) builds it here instead of
/// adding to the corpus, so the differential gate keeps comparing two
/// implementations over identical bytes.
struct TemporaryRepository: ~Copyable {
    let repository: String
    let root: String

    init(repository: String = "swift-institute-test/fixture") {
        self.repository = repository
        self.root = NSTemporaryDirectory() + "institute-ci-tests/" + UUID().uuidString
        try? FileManager.default.createDirectory(
            atPath: root,
            withIntermediateDirectories: true
        )
    }

    var subject: GitHub.ContinuousIntegration.Validation.Subject {
        GitHub.ContinuousIntegration.Validation.Subject(repository: repository, root: root)
    }

    /// Write `contents` at a path relative to the root, creating
    /// intermediate directories.
    func write(_ contents: String, to relative: String) {
        let path = root + "/" + relative
        // Retried on Windows: a hosted runner's real-time scanner can
        // transiently hold a freshly created path under the temporary
        // root, which surfaces as `ERROR_SHARING_VIOLATION` — see
        // `Gitignore.retryingTransientWindowsFailures`. `write` returns
        // `Void` and this fixture's callers already assume success, so
        // a still-losing retry fails the same way it always has
        // (silently) rather than gaining new behavior.
        try? ContinuousIntegration.Validation.Gitignore.retryingTransientWindowsFailures {
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
        }
        try? ContinuousIntegration.Validation.Gitignore.retryingTransientWindowsFailures {
            try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
        }
    }

    /// The absolute path of a file written into this repository.
    func path(_ relative: String) -> String { root + "/" + relative }

    /// Run Git inside the temporary repository. Test setup failures are
    /// surfaced through the returned status rather than hidden.
    @discardableResult
    func git(_ arguments: [String], environment: [String: String]? = nil) throws -> Int32 {
        guard
            let executable = ContinuousIntegration.Validation.Gitignore.gitExecutable(
                in: ProcessInfo.processInfo.environment
            )
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = URL(filePath: root)
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) {
                _,
                value in value
            }
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    deinit {
        try? FileManager.default.removeItem(atPath: root)
    }
}
