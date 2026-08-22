public import Institute_Continuous_Integration
public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Institute_Source_Profile
public import Institute_Source_Workspace

extension Institute.Source.Profile {
  public func bundle(for repository: Institute.Repository) -> ContinuousIntegration.Source.Bundle {
    switch repository.layer {
    case .primitives: .primitives
    case .standards: .standards
    case .foundations, .components, .applications: .institute
    }
  }

  public func bundle(
    for row: Institute.Source.Workspace.Row
  ) throws(Institute.Error) -> ContinuousIntegration.Source.Bundle {
    switch row.role {
    case .control: return .institute
    case .subject:
      guard let repository = row.repository else {
        throw .configuration("source subject has no inventory binding: \(row.identity)")
      }
      return bundle(for: repository)
    }
  }
}
