internal import Institute_Inventory
internal import Institute_Model

extension Institute.Dependency.Pending {
  struct Edge: Equatable, Sendable {
    let repository: Institute.Repository.Key
    let manifest: Swift.String
    let reference: Swift.String
    let revision: Swift.String
    let line: Swift.Int
    let declaredURL: Swift.String
    let declared: Institute.Repository.Key
  }
}
