public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Index.Artifact {
    /// Why a versioned Architecture Index artifact cannot be emitted or
    /// verified.
    public enum Error: Swift.Error, Sendable, Equatable {
        case incompleteMeasurement([Institute.Architecture.Owner])
        case invalidCoverage
        case invalidFact
        case invalidValidation
        case malformed
        case unsupportedSchema(Swift.String)
        case digestMismatch(expected: Swift.String, actual: Swift.String)
    }
}
