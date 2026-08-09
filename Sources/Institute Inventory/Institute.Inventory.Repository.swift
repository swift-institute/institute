public import GitHub
public import Institute_Model
public import Tagged_Primitives

extension Institute.Inventory {
  public struct Repository: Equatable, Sendable {
    public let id: GitHub.Repository.ID
    public let key: Institute.Repository.Key
    public let layer: Institute.Layer

    public init(
      id: GitHub.Repository.ID,
      key: Institute.Repository.Key,
      layer: Institute.Layer
    ) {
      self.id = id
      self.key = key
      self.layer = layer
    }
  }
}
