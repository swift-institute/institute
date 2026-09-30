public import Institute_Model
import struct Swift.String
import Byte
public import Institute_CI_Model
import File_System

// The validation rules read repository trees through these accessors so
// each rule states *what* it reads — a file's text, a directory's entry
// names, a subtree's files — and the kernel-backed mechanics stay in one
// place. Every absence collapses to `nil`/`false`/empty on purpose: a
// validator's contract is to report findings about what is there, and
// "not there" is an input state, not an error path.
extension Institute.CI.Validation {

    /// The UTF-8 text of the file at `path`, or `nil` when the path is
    /// invalid, missing, or unreadable.
    internal static func text(at path: Swift.String) -> Swift.String? {
        guard let filePath = try? File.Path(path) else { return nil }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(filePath).read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            return nil
        }
    }

    /// The strictly decoded UTF-8 text of the file at `path`, or `nil`
    /// when the path is invalid, missing, unreadable, or not valid
    /// UTF-8. Rules whose findings report undecodable files use this
    /// reader; a lossy read would turn that finding into a silent pass.
    internal static func strictText(at path: Swift.String) -> Swift.String? {
        guard let filePath = try? File.Path(path) else { return nil }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(filePath).read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(validating: storage, as: Swift.UTF8.self)
            }
        } catch {
            return nil
        }
    }

    /// The entry names of the directory at `path`, or `nil` when the
    /// path is invalid, missing, or not a directory.
    internal static func names(at path: Swift.String) -> [Swift.String]? {
        guard let filePath = try? File.Path(path) else { return nil }
        guard let entries = try? File.Directory.Contents.list(at: .init(filePath)) else {
            return nil
        }
        return entries.map { Swift.String(lossy: $0.name) }
    }

    /// Whether anything exists at `path`.
    internal static func exists(_ path: Swift.String) -> Swift.Bool {
        guard let filePath = try? File.Path(path) else { return false }
        return File.System.Stat.exists(at: filePath)
    }

    /// Whether a directory exists at `path`.
    internal static func isDirectory(_ path: Swift.String) -> Swift.Bool {
        guard let filePath = try? File.Path(path) else { return false }
        return File(filePath).stat.isDirectory
    }

    /// Whether a regular file exists at `path`.
    internal static func isFile(_ path: Swift.String) -> Swift.Bool {
        guard let filePath = try? File.Path(path) else { return false }
        return File(filePath).stat.isFile
    }

    /// Every regular file under `path`, as slash-joined paths relative
    /// to `path`, sorted. Empty when the path is invalid or missing.
    internal static func filesRecursively(at path: Swift.String) -> [Swift.String] {
        var results: [Swift.String] = []
        walk(path, relative: "", into: &results)
        return results.sorted()
    }

    private static func walk(
        _ directory: Swift.String,
        relative prefix: Swift.String,
        into results: inout [Swift.String]
    ) {
        guard let entries = names(at: directory)?.sorted() else { return }
        for name in entries {
            let child = "\(directory)/\(name)"
            let relative = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if isDirectory(child) {
                walk(child, relative: relative, into: &results)
            } else {
                results.append(relative)
            }
        }
    }
}
