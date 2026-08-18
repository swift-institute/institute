public import Institute_Model
public import JSON

extension Institute.Certification {
    /// Whether a certificate still describes the current fleet — a
    /// *derived* comparison against the complete certified input
    /// identity, never a stored flag.
    ///
    /// A certificate is `current` only while every member revision it
    /// certified still equals the observed canonical revision AND the
    /// control inputs that judged it (certifier, toolchain, CI policy)
    /// still equal the observed control identity (.github#600: heads and
    /// control inputs both freeze a certificate). Any movement makes it
    /// `superseded`; the certificate remains valid historical evidence
    /// about its immutable input.
    public enum Status: Equatable, Sendable {
        case current
        case superseded(moved: [Institute.Repository.Key], controlMoved: Swift.Bool)
    }
}

extension Institute.Certification.Certificate {
    /// Compare this certificate's complete certified input identity
    /// against the observed canonical revisions and the observed control
    /// identity.
    ///
    /// `observed` must cover every snapshot member: a member whose current
    /// revision could not be observed counts as moved — unknown is never
    /// current. Control movement supersedes exactly as head movement does.
    public func status(
        against observed: [Institute.Repository.Key: Institute.Certification.Revision],
        control current: Institute.Certification.Control
    ) -> Institute.Certification.Status {
        let moved = snapshot.members
            .filter { observed[$0.key] != $0.revision }
            .map(\.key)
        let controlMoved = current != control
        return moved.isEmpty && !controlMoved
            ? .current
            : .superseded(moved: moved, controlMoved: controlMoved)
    }
}
