public import Byte
public import Institute_Model

extension Institute.Planner {
    /// swift-institute/.github's default branch as the canary reads it:
    /// the bytes of one file there. The closure is the network boundary;
    /// tests bind it to fixture files.
    public struct Consumer: Sendable {
        public typealias Read = @Sendable (Swift.String) throws(Institute.Planner.Error) -> [Byte]

        public let read: Read

        public init(read: @escaping Read) {
            self.read = read
        }
    }
}

extension Institute.Planner.Consumer {
    public static let pin = ".institute-ci-pin"
    public static let ledger = ".institute-ci-planner"

    /// The pin the consumer's default branch holds.
    public func pin() throws(Institute.Planner.Error) -> Institute.Planner.Pin {
        try .init(text: Swift.String(decoding: try read(Self.pin), as: Swift.UTF8.self))
    }

    /// The planner rows the consumer's default branch holds.
    public func ledger() throws(Institute.Planner.Error) -> Institute.Planner.Ledger {
        try .init(text: Swift.String(decoding: try read(Self.ledger), as: Swift.UTF8.self))
    }

    /// The row the consumer's default branch runs on `platform`: the
    /// winning row for the pinned revision.
    public func current(
        _ platform: Institute.Planner.Platform
    ) throws(Institute.Planner.Error) -> Institute.Planner.Row {
        let pin = try pin()
        guard let row = try ledger().winner(pin.revision, platform) else {
            throw .absent(revision: pin.revision.description, platform: platform.rawValue)
        }
        return row
    }
}
