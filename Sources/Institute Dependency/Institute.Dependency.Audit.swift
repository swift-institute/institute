public import Async_Fanout
public import Institute_Inventory
public import Institute_Model
public import SPM_Standard

extension Institute.Dependency {
  /// Reproducible, read-only measurement of direct manifest dependency
  /// origins over the Institute inventory.
  public struct Audit: Sendable {
    public let repositories: [Institute.Repository]
    public let policy: Institute.Inventory.Policy
    public let client: Client
    public let sanctioned: Set<Institute.Repository.Key>
    public let inventoryReference: Swift.String
    public let inventoryRevision: Swift.String
    public let parser: Package.Dependency.Declaration.Parser
    public let fanout: Async.Fanout

    public init(
      repositories: [Institute.Repository],
      policy: Institute.Inventory.Policy,
      client: Client,
      sanctioned: Set<Institute.Repository.Key> = [],
      inventoryReference: Swift.String,
      inventoryRevision: Swift.String,
      parser: Package.Dependency.Declaration.Parser = .init(),
      fanout: Async.Fanout = .init()
    ) {
      self.repositories = repositories
      self.policy = policy
      self.client = client
      self.sanctioned = sanctioned
      self.inventoryReference = inventoryReference
      self.inventoryRevision = inventoryRevision
      self.parser = parser
      self.fanout = fanout
    }
  }
}
