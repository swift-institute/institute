public import GitHub
public import Institute_Model
public import Tagged_Primitives

extension Institute.Inventory.Merge {
  public enum Error: Swift.Error, Equatable, Sendable {
    case annotation(Institute.Repository)
    case duplicate(Institute.Repository.Key)
    case collision(
      GitHub.Repository.Name,
      Institute.Repository.Key,
      Institute.Repository.Key
    )
    case transfer(
      GitHub.Repository.Name,
      Institute.Repository.Key,
      Institute.Repository.Key,
      annotation: Institute.Layer,
      default: Institute.Layer
    )
  }
}
