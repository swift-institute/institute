import Byte
import File_System
public import Institute_Model
public import Institute_Repository_Policy

import struct Swift.String

extension Institute.Repository.Policy.Command {
    /// The bytes of the file at `path`, or a typed refusal naming the
    /// evidence that could not be read.
    static func bytes(at path: Swift.String, label: Swift.String) throws(Error) -> [Byte] {
        guard let filePath = try? File.Path(path) else {
            throw .io("could not read \(label) at \(path): invalid path")
        }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(filePath).read.full { view in
                var storage = [Byte]()
                storage.reserveCapacity(view.count)
                for index in view.indices {
                    storage.append(view[index])
                }
                return storage
            }
        } catch {
            throw .io("could not read \(label) at \(path): \(error)")
        }
    }

    static func text(at path: Swift.String, label: Swift.String) throws(Error) -> Swift.String {
        Swift.String(decoding: try bytes(at: path, label: label), as: Swift.UTF8.self)
    }

    static func write(_ bytes: [Byte], to path: Swift.String) throws(Error) {
        guard let filePath = try? File.Path(path) else {
            throw .io("could not encode \(path): invalid path")
        }
        try createParent(of: filePath, at: path)
        do throws(File.System.Write.Atomic.Error) {
            try File(filePath).write.atomic(contentsOf: bytes)
        } catch {
            throw Error.io("could not encode \(path): \(error)")
        }
    }

    private static func createParent(
        of filePath: File.Path,
        at path: Swift.String
    ) throws(Error) {
        guard let parent = File.Directory(filePath).parent else { return }
        do throws(File.System.Create.Directory.Error) {
            try parent.create.recursive()
        } catch {
            throw Error.io("could not create the directory for \(path): \(error)")
        }
    }
}
