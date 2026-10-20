import Byte
import File_System
import Institute_Model

extension Institute.Planner {
    /// A path the verbs were handed or derived.
    static func path(_ text: Swift.String) throws(Error) -> File.Path {
        do throws(File.Path.Error) {
            return try File.Path(text)
        } catch {
            throw .local("invalid path \(text): \(error)")
        }
    }

    /// The bytes of the file at `path`.
    static func read(_ path: File.Path) throws(Error) -> [Byte] {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File.System.Read.Full.read(from: path) { span in
                var bytes: [Byte] = []
                bytes.reserveCapacity(span.count)
                for index in span.indices { bytes.append(span[index]) }
                return bytes
            }
        } catch {
            throw .local("cannot read \(path): \(error)")
        }
    }

    /// Replaces the file at `path` with `bytes`, atomically.
    static func write(_ bytes: [Byte], to path: File.Path) throws(Error) {
        do throws(File.System.Write.Atomic.Error) {
            try File(path).write.atomic(contentsOf: bytes)
        } catch {
            throw .local("cannot write \(path): \(error)")
        }
    }

    /// Creates the directory at `path` and any missing parents.
    static func directory(_ path: File.Path) throws(Error) {
        do throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(at: path, createIntermediates: true)
        } catch {
            throw .local("cannot create \(path): \(error)")
        }
    }
}
