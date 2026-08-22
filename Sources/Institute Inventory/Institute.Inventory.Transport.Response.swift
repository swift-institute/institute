public import Byte_Primitives
public import Institute_Model

extension Institute.Inventory.Transport {
    public struct Response: Equatable, Sendable {
        public let status: Swift.Int
        public let headers: [Swift.String: Swift.String]
        public let body: [Byte]?

        public init(
            status: Swift.Int,
            headers: [Swift.String: Swift.String] = [:],
            body: [Byte]? = nil
        ) {
            self.status = status
            var normalized = [Swift.String: Swift.String]()
            for (key, value) in headers { normalized[key.lowercased()] = value }
            self.headers = normalized
            self.body = body
        }

        public func header(_ name: Swift.String) -> Swift.String? {
            headers[name.lowercased()]
        }
    }
}
