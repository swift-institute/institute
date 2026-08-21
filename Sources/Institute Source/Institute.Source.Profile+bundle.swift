public import Institute_Continuous_Integration_Source
public import Institute_Model

extension Institute.Source.Profile {
    public func bundle(for repository: Institute.Repository) -> Institute.ContinuousIntegration.Source.Bundle {
        switch repository.layer {
        case .primitives: .primitives
        case .standards: .standards
        case .foundations, .components, .applications: .institute
        }
    }
}
