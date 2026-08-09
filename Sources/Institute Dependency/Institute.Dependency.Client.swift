public import Byte_Primitives
public import Institute_Inventory
public import Institute_Model

extension Institute.Dependency {
  /// The three remote reads the audit composes.
  ///
  /// Tests supply controlled repositories and failures. The command supplies
  /// the GitHub-backed client, keeping transport and measurement independent.
  public struct Client: Sendable {
    public let repository: @Sendable (Institute.Repository.Key) async -> Fetch<Metadata>
    public let source: @Sendable (Metadata) async -> Fetch<Source>
    public let content: @Sendable (Institute.Repository.Key, Source.Blob) async -> Fetch<[Byte]>

    public init(
      repository:
        @escaping @Sendable (Institute.Repository.Key) async -> Fetch<Metadata>,
      source:
        @escaping @Sendable (Metadata) async -> Fetch<Source>,
      content:
        @escaping @Sendable (
          Institute.Repository.Key,
          Source.Blob
        ) async -> Fetch<[Byte]>
    ) {
      self.repository = repository
      self.source = source
      self.content = content
    }
  }
}
