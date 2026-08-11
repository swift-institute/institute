extension Institute.Peer {
  /// One peer's printable inventory report — the peer counterpart of
  /// ``Institute/Inventory/Register``, rendered by `institute inventory`.
  ///
  /// A view of an already resolved ``Institute/Peer/Presence``; it
  /// performs no discovery and has no write capability. Paths are
  /// entry-relative — the peer's name followed by the record's
  /// ``Institute/Peer/Layout`` reference — never absolute.
  public struct Report: Equatable, Sendable {
    public let peer: Institute.Peer
    public let presence: Presence

    public init(peer: Institute.Peer, presence: Presence) {
      self.peer = peer
      self.presence = presence
    }
  }
}

extension Institute.Peer.Report: CustomStringConvertible {
  public var description: Swift.String {
    switch presence {
    case .absent:
      return "peer \(peer.name): not materialized (opt-in)"

    case .missing(let path):
      return "peer \(peer.name): materialized without an inventory at \(path)"

    case .invalid(let reason):
      return "peer \(peer.name): inventory unusable — \(reason)"

    case .declared(let configuration):
      return
        ([
          "peer \(peer.name): \(configuration.repositories.count) repositories "
            + "(name → organization → path)"
        ]
        + configuration.repositories.map { repository in
          "  \(repository.name) → \(repository.organization) → "
            + "\(peer.name)/"
            + Institute.Peer.Layout.reference(for: repository, in: peer.name)
        })
        .joined(separator: "\n")
    }
  }
}
