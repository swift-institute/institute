import Byte
import File_System
public import Institute_Model
public import Institute_Repository_Policy
import JSON

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

    static func decode<T: JSON.Serializable>(
        at path: Swift.String,
        label: Swift.String
    ) throws(Error) -> T {
        let bytes = try bytes(at: path, label: label)
        do throws(JSON.Error) {
            return try T(jsonBytes: bytes)
        } catch {
            throw .io("could not decode \(label) at \(path): \(error)")
        }
    }

    static func decodeDirectory<T: JSON.Serializable>(
        at path: Swift.String,
        label: Swift.String
    ) throws(Error) -> [T] {
        var result: [T] = []
        for file in try evidencePaths(at: path, label: label) {
            result.append(try decode(at: file, label: label))
        }
        return result
    }

    static func decodeLinesDirectory<T: JSON.Serializable>(
        at path: Swift.String,
        label: Swift.String
    ) throws(Error) -> [T] {
        var result: [T] = []
        for file in try evidencePaths(at: path, label: label) {
            let bytes = try bytes(at: file, label: label)
            for line in bytes.split(separator: Byte(0x0A)) {
                do throws(JSON.Error) {
                    result.append(try T(jsonBytes: Array(line)))
                } catch {
                    throw Error.io("could not decode \(label) at \(file): \(error)")
                }
            }
        }
        return result
    }

    private static func evidencePaths(
        at path: Swift.String,
        label: Swift.String
    ) throws(Error) -> [Swift.String] {
        guard let filePath = try? File.Path(path) else {
            throw .io("could not enumerate \(label) at \(path): invalid path")
        }
        guard let entries = try? File.Directory.Contents.list(at: .init(filePath)) else {
            throw .io("could not enumerate \(label) at \(path)")
        }
        let names = entries.map { Swift.String(lossy: $0.name) }
            .filter { $0.hasSuffix(".json") || $0.hasSuffix(".jsonl") }
            .sorted()
        guard !names.isEmpty else { throw Error.io("\(label) directory is empty: \(path)") }
        return names.map { path + "/" + $0 }
    }

    /// Writes one evidence document: the exact canonical bytes the
    /// library digests, so recorded digests equal an independent file
    /// checksum.
    static func encode<T: JSON.Serializable>(
        _ value: T,
        to path: Swift.String
    ) throws(Error) {
        try write(
            Institute.Repository.Policy.Caller.Wave.evidenceBytes(value),
            to: path
        )
    }

    /// Appends one JSON line to a journal, creating it (and its
    /// directory) when absent.
    static func append<T: JSON.Serializable>(
        _ value: T,
        to path: Swift.String
    ) throws(Error) {
        var bytes = [Byte](utf8: value.jsonString(sortKeys: true))
        bytes.append(Byte(0x0A))
        guard let filePath = try? File.Path(path) else {
            throw .io("could not append \(path): invalid path")
        }
        try createParent(of: filePath, at: path)
        do throws(File.System.Write.Append.Error) {
            try File(filePath).write.append(bytes.span)
        } catch {
            throw Error.io("could not append \(path): \(error)")
        }
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
