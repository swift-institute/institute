extension Source.Repair {
    public struct FileSystem: Sendable {
        public let exists: @Sendable (Swift.String) -> Swift.Bool
        public let read: @Sendable (Swift.String) -> Result<[UInt8], Source.Reason>
        public let write: @Sendable (Swift.String, [UInt8]) -> Result<Void, Source.Reason>
        public let move: @Sendable (Swift.String, Swift.String) -> Result<Void, Source.Reason>
        public let delete: @Sendable (Swift.String) -> Result<Void, Source.Reason>

        public init(
            exists: @escaping @Sendable (Swift.String) -> Swift.Bool,
            read: @escaping @Sendable (Swift.String) -> Result<[UInt8], Source.Reason>,
            write: @escaping @Sendable (Swift.String, [UInt8]) -> Result<Void, Source.Reason>,
            move: @escaping @Sendable (Swift.String, Swift.String) -> Result<Void, Source.Reason>,
            delete: @escaping @Sendable (Swift.String) -> Result<Void, Source.Reason>
        ) {
            self.exists = exists
            self.read = read
            self.write = write
            self.move = move
            self.delete = delete
        }
    }
}
