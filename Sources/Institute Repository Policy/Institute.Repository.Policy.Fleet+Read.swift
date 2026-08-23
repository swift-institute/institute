public import Institute_Model
import Byte_Primitives
import File_System
import JSON

extension Institute.Repository.Policy.Fleet {
    /// Reads and validates one fleet policy document from disk. The
    /// document format and every structural rule stay with the domain;
    /// this extension owns only the filesystem boundary.
    public static func read(at path: Swift.String) throws(Error) -> Self {
        guard let filePath = try? File.Path(path) else { throw .unreadable }
        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try File(filePath).read.full { view in
                var storage = [Byte]()
                storage.reserveCapacity(view.count)
                for index in view.indices {
                    storage.append(view[index])
                }
                return storage
            }
        } catch {
            throw .unreadable
        }
        let value: JSON
        do throws(JSON.Error) {
            value = try JSON.parse(bytes)
        } catch {
            throw .invalid
        }
        let fleet: Self
        do throws(Swift.DecodingError) {
            fleet = try value.decode(Self.self)
        } catch {
            throw .invalid
        }
        try fleet.validate()
        return fleet
    }
}
