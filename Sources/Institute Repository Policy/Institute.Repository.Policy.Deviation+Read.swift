import Byte
import File_System
public import Institute_Model

extension Institute.Repository.Policy.Deviation {
    public static func read(root: Swift.String) -> Self {
        guard let filePath = try? File.Path("\(root)/\(Self.path)") else { return Self() }
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
            return Self()
        }
        return Self(metadata: Swift.String(decoding: bytes, as: Swift.UTF8.self))
    }
}
