public import GitHub
public import Institute_Inventory
public import Institute_Model

extension Institute.Dependency {
  /// Live repository metadata needed to establish eligibility and ownership.
  public struct Metadata: Equatable, Sendable {
    public let key: Institute.Repository.Key
    public let ownerIsUser: Swift.Bool
    public let visibility: GitHub.Repository.Visibility
    public let archived: Swift.Bool
    public let disabled: Swift.Bool
    public let defaultBranch: Swift.String

    public init(
      key: Institute.Repository.Key,
      ownerIsUser: Swift.Bool,
      visibility: GitHub.Repository.Visibility,
      archived: Swift.Bool,
      disabled: Swift.Bool,
      defaultBranch: Swift.String
    ) {
      self.key = key
      self.ownerIsUser = ownerIsUser
      self.visibility = visibility
      self.archived = archived
      self.disabled = disabled
      self.defaultBranch = defaultBranch
    }
  }
}
