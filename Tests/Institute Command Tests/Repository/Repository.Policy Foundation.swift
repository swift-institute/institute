import Byte
import Foundation

enum RepositoryPolicyFoundation {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }

    static func decode<T: Decodable>(_ type: T.Type, contentsOf url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    static func bytes(contentsOf url: URL) throws -> [Byte] {
        try Data(contentsOf: url).map { Byte(bitPattern: $0) }
    }

    static func jsonObject<Bytes: Sequence>(with bytes: Bytes) throws -> Any where Bytes.Element == UInt8 {
        try JSONSerialization.jsonObject(with: Data(bytes))
    }

    static func data(withJSONObject object: [String: Any]) throws -> [Byte] {
        try JSONSerialization.data(withJSONObject: object).map { Byte(bitPattern: $0) }
    }

    static func substitute(of target: String, with replacement: String, in text: String) -> String {
        text.replacingOccurrences(of: target, with: replacement)
    }
}
