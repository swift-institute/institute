internal import Institute_Development
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor.Uniqueness {
    /// The result of reading one materialized repository's manifest for
    /// the name-uniqueness gather.
    ///
    /// `absent` is a repository with no `Package.swift` — a specification
    /// or document repository that contributes nothing to either
    /// namespace, exactly as it contributes nothing to the composed
    /// graph. `unevaluable` is a manifest that failed to evaluate; the
    /// gather turns it into an `unmeasured` outcome, because a manifest
    /// whose names cannot be read leaves uniqueness unproven.
    public enum Reading: Equatable, Sendable {
        case declared(Declaration)
        case absent
        case unevaluable(repository: Swift.String, diagnostic: Swift.String)
    }
}
