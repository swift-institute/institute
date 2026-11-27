public import Institute_Model
public import JSON
internal import Byte
internal import File_System

extension Institute.Inventory {
    /// One output file: a JSON array of flat objects, fields in a fixed order.
    public struct Table: Sendable {
        public enum Field: Sendable, Hashable {
            case text(Swift.String)
            case number(Swift.Int)
            case flag(Swift.Bool)
        }

        public typealias Row = [(Swift.String, Field)]

        public let name: Swift.String
        public var rows: [Row]

        public init(name: Swift.String, rows: [Row] = []) {
            self.name = name
            self.rows = rows
        }

        /// `[` one object per line `]`, so `sqlite3` reads it with
        /// `json_each(readfile(…))` and a diff stays readable.
        public var bytes: [Swift.UInt8] {
            var bytes: [Swift.UInt8] = [0x5B]
            for (offset, row) in rows.enumerated() {
                bytes.append(contentsOf: offset == 0 ? [0x0A] : [0x2C, 0x0A])
                let object = JSON.object(
                    row.map { key, field in
                        switch field {
                        case .text(let value): (key, .string(value))
                        case .number(let value): (key, .number(value))
                        case .flag(let value): (key, .bool(value))
                        }
                    }
                )
                bytes.append(contentsOf: object.serialize(as: [Swift.UInt8].self))
            }
            bytes.append(contentsOf: [0x0A, 0x5D, 0x0A])
            return bytes
        }

        func write(into directory: Swift.String) throws(Institute.Error) {
            let path = directory + "/" + name + ".json"
            let file: File
            do throws(File.Path.Error) {
                file = File(try File.Path(path))
            } catch {
                throw .filesystem("\(path) is not a path: \(error)")
            }
            do throws(File.System.Write.Atomic.Error) {
                try file.write.atomic(contentsOf: bytes.lazy.map { Byte(bitPattern: $0) })
            } catch {
                throw .filesystem("cannot write \(path): \(error)")
            }
        }
    }
}
