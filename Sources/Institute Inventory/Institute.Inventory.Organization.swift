public import GitHub
public import Institute_Model
public import Tagged_Primitives

extension Institute.Inventory {
  public struct Organization: Equatable, Hashable, Sendable {
    public let name: GitHub.Organization.Name
    public let layer: Institute.Layer

    public init(name: GitHub.Organization.Name, layer: Institute.Layer) {
      self.name = name
      self.layer = layer
    }
  }
}
