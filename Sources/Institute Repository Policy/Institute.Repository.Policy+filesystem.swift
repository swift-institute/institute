import File_System
import Institute_Model

import struct Swift.String

// The policy scans read checked-out trees through these accessors so the
// kernel-backed mechanics stay in one place. Absence collapses to
// `nil`/`false`: each scan decides whether a missing directory is a
// refusal or simply contributes nothing.
extension Institute.Repository.Policy {
    /// The entry names of the directory at `path`, or `nil` when the
    /// path is invalid, missing, or not a directory.
    static func names(at path: Swift.String) -> [Swift.String]? {
        guard let filePath = try? File.Path(path) else { return nil }
        guard let entries = try? File.Directory.Contents.list(at: .init(filePath)) else {
            return nil
        }
        return entries.map { Swift.String(lossy: $0.name) }
    }

    /// Whether a directory exists at `path`.
    static func isDirectory(at path: Swift.String) -> Swift.Bool {
        guard let filePath = try? File.Path(path) else { return false }
        return File(filePath).stat.isDirectory
    }
}
