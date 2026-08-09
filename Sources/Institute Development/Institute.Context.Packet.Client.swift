public import Institute_Inventory
public import Institute_Model

extension Institute.Context.Packet {
  /// The packet's read-only boundary. Tests provide a fixed record, while the
  /// command uses the GitHub-backed implementation below.
  public struct Client: Sendable {
    public let record:
      @Sendable (Institute.Context.Packet.Key, [Swift.String]) async
        -> Institute.Context.Packet.Fetch<Institute.Context.Packet.Record>
  }
}
