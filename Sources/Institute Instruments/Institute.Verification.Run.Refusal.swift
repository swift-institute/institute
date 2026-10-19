public import Institute_Development
public import Institute_Doctor
public import Institute_Inventory
public import Institute_Model

extension Institute.Verification.Run {
    /// Why a lint leg produced no measurement, in a form that can cross the
    /// receipt boundary.
    ///
    /// **Why this type exists (R34.1).** The lint leg's reason used to be
    /// free text interpolating the subject's absolute path — `"cannot run
    /// the lint gate at \(path): \(error)"` — and it forwarded the linter's
    /// own unmeasured reason verbatim, which likewise quotes absolute
    /// package and hierarchy paths. ``Institute/Verification/Redaction``
    /// rightly refuses to seal a receipt carrying an absolute machine path,
    /// so a lint leg that went unmeasured could never seal *at all*: the
    /// refusal was not a lint failure but an instrument defect, and it is
    /// the original cause of the lint leg being dropped from the requested
    /// contract rather than fixed.
    ///
    /// Every case below names a stage and, where one exists, the leak-safe
    /// ``Institute/Error/Kind`` of the failure. None interpolates a path, a
    /// command line, or any captured text, so none can be refused by
    /// ``Institute/Verification/Redaction`` — the reason a reader gets is
    /// smaller than the old free text but, unlike it, actually arrives.
    public enum Refusal: Equatable, Sendable, CustomStringConvertible {
        /// The subject could not be bound as a source subject at its
        /// claimed head.
        case unresolvableSubject(Institute.Error.Kind)
        /// The policy-pinned source engines and profiles could not be
        /// prepared for the subject.
        case unavailablePreparation(Institute.Error.Kind)
        /// The prepared measurement could not run.
        case unavailableMeasurement(Institute.Error.Kind)
        /// The measurement declined to measure, but its own reason carries
        /// content this instrument will not seal. The full reason is still
        /// printed by `institute source measure` locally; only the receipt
        /// withholds it.
        case unsealableMeasurementReason
    }
}

extension Institute.Verification.Run.Refusal {
    public var description: Swift.String {
        switch self {
        case .unresolvableSubject(let kind):
            "the lint gate could not bind the subject at its claimed head (\(kind))"

        case .unavailablePreparation(let kind):
            "the lint gate could not prepare the pinned source engines (\(kind))"

        case .unavailableMeasurement(let kind):
            "the lint gate could not run the source measurement (\(kind))"

        case .unsealableMeasurementReason:
            "the lint gate declined to measure, for a reason that cannot cross the receipt "
                + "boundary"
        }
    }
}
