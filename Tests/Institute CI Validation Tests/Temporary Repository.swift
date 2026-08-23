public import Institute_Model
import struct Swift.String
import Foundation
import Institute_CI_Model
import Institute_CI_Validation
import GitHub_Standard
import Process

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

    var subject: Institute.CI.Validation.Subject {
        Institute.CI.Validation.Subject(repository: repository, root: root)
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
        try? Institute.CI.Validation.Gitignore.retryingTransientWindowsFailures {
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
        }
        try? Institute.CI.Validation.Gitignore.retryingTransientWindowsFailures {
            try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
        }
    }

    /// The absolute path of a file written into this repository.
    func path(_ relative: String) -> String { root + "/" + relative }

    /// Run Git inside the temporary repository with the ambient
    /// environment plus the caller's overrides — the setup seam stays
    /// ambient on purpose, so the validator's own environment isolation
    /// remains the thing under test. Setup failures surface through the
    /// returned status rather than hidden.
    @discardableResult
    func git(_ arguments: [String], environment: [String: String]? = nil) throws -> Int32 {
        let executable = try Process.Spawn.Executable.resolve("git")
        var merged = ProcessInfo.processInfo.environment
        if let environment {
            merged.merge(environment) { _, value in value }
        }
        let output = try Process.Spawn.run(
            .init(
                executable: executable,
                arguments: ["-C", root] + arguments,
                environment: merged,
                stdin: .inherit,
                stdout: .pipe,
                stderr: .pipe
            )
        )
        guard case .exited(let code) = output.status else { return -1 }
        return code
    }

    deinit {
        try? FileManager.default.removeItem(atPath: root)
    }
}
