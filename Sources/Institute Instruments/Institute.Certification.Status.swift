public import Institute_Model
public import JSON

extension Institute.Certification {
    /// Whether a certificate still describes the current fleet — a
    /// *derived* comparison against observed canonical heads, never a
    /// stored flag.
    ///
    /// A certificate is `current` only while every member revision it
    /// certified still equals the observed canonical revision. Any
    /// movement makes it `superseded`, naming the moved members; the
    /// certificate itself remains valid historical evidence about its
    /// immutable snapshot.
    public enum Status: Equatable, Sendable {
        case current
        case superseded(moved: [Institute.Repository.Key])
    }
}

extension Institute.Certification.Certificate {
    /// Compare this certificate's snapshot against observed canonical
    /// revisions.
    ///
    /// `observed` must cover every snapshot member: a member whose current
    /// revision could not be observed counts as moved — unknown is never
    /// current.
    public func status(
        against observed: [Institute.Repository.Key: Institute.Certification.Revision]
    ) -> Institute.Certification.Status {
        let moved = snapshot.members
            .filter { observed[$0.key] != $0.revision }
            .map(\.key)
        return moved.isEmpty ? .current : .superseded(moved: moved)
    }
}
