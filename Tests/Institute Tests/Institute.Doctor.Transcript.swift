import Foundation

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Doctor {
    /// A ``Institute/Doctor/Progress`` that keeps what a run said instead
    /// of printing it, so a test can assert on the transcript.
    ///
    /// Locked rather than plain: a run reports from the context consuming
    /// its fan-outs, and a test that asserted on an unsynchronised buffer
    /// would be asserting on the synchronisation, not the transcript.
    final class Transcript: Sendable {
        nonisolated(unsafe) private var storage = [Swift.String]()
        private let lock = NSLock()

        var lines: [Swift.String] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        var progress: Institute.Doctor.Progress {
            .init { [self] message in
                lock.lock()
                defer { lock.unlock() }
                storage.append(contentsOf: message.split(separator: "\n").map(Swift.String.init))
            }
        }
    }
}
