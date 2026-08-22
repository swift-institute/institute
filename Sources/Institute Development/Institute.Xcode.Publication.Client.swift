public import File_System
public import Institute_Model

extension Institute.Xcode.Publication {
    public struct Client: Sendable {
        public let read: @Sendable (File) throws(Institute.Error) -> Swift.String?
        public let write: @Sendable (File, Swift.String) throws(Institute.Error) -> Swift.Void
        public let delete: @Sendable (File) throws(Institute.Error) -> Swift.Void

        public init(
            read: @escaping @Sendable (File) throws(Institute.Error) -> Swift.String?,
            write: @escaping @Sendable (File, Swift.String) throws(Institute.Error) -> Swift.Void,
            delete: @escaping @Sendable (File) throws(Institute.Error) -> Swift.Void
        ) {
            self.read = read
            self.write = write
            self.delete = delete
        }

        public static let live = Self(
            read: readLive,
            write: writeLive,
            delete: deleteLive
        )

        private static func readLive(_ file: File) throws(Institute.Error) -> Swift.String? {
            guard file.stat.exists else { return nil }
            do throws(Either<File.System.Read.Full.Error, Never>) {
                return try file.read.full { bytes in
                    var storage = [Byte]()
                    storage.reserveCapacity(bytes.count)
                    for index in bytes.indices { storage.append(bytes[index]) }
                    return Swift.String(decoding: storage, as: Swift.UTF8.self)
                }
            } catch {
                throw .filesystem("cannot capture publication preimage \(file): \(error)")
            }
        }

        private static func writeLive(
            _ file: File,
            _ contents: Swift.String
        ) throws(Institute.Error) {
            guard let parent = file.path.parent else {
                throw .filesystem("publication destination has no parent: \(file)")
            }
            do {
                try File.Directory(parent).create.recursive()
                try file.write.atomic(contents)
            } catch {
                throw .filesystem("cannot write publication destination \(file): \(error)")
            }
        }

        private static func deleteLive(_ file: File) throws(Institute.Error) {
            guard file.stat.exists else { return }
            do {
                try file.delete()
            } catch {
                throw .filesystem("cannot delete publication destination \(file): \(error)")
            }
        }
    }
}
