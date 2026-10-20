public import Institute_Model

extension Institute.Planner {
    /// One verified adoption of a publish run by the consumer: the new
    /// `.institute-ci-pin` and `.institute-ci-planner` contents and the
    /// message of the one commit that records them.
    public struct Adoption: Sendable {
        public let revision: Revision
        public let run: Swift.String
        public let pin: Swift.String
        public let ledger: Swift.String
        public let message: Swift.String
    }
}

extension Institute.Planner.Adoption {
    public static let paths = [Institute.Planner.Consumer.pin, Institute.Planner.Consumer.ledger]

    /// Derives the adoption of publish run `run` from adoptable canary
    /// `evidence` for that run, and verifies the result against the
    /// contract before returning it.
    ///
    /// The appended rows are the publication's PIN lines as the release
    /// carries them now, never the evidence's copy; the evidence's copy
    /// must agree with them.
    public init(
        evidence: Institute.Planner.Evidence,
        run: Swift.String,
        pin: Institute.Planner.Pin,
        ledger: Institute.Planner.Ledger,
        release: Institute.Planner.Release
    ) throws(Institute.Planner.Error) {
        guard evidence.run == run else {
            throw .evidence("the evidence is for publish run \(evidence.run), not \(run)")
        }
        guard evidence.verdict == .adoptable else {
            throw .evidence(
                "the evidence verdict is \(evidence.verdict.rawValue); only adoptable evidence is adopted"
            )
        }
        let publication = try release.publication(run: run)
        guard publication.revision.description == evidence.revision else {
            throw .evidence(
                "the evidence judged revision \(evidence.revision), but publish run \(run) is \(publication.revision)"
            )
        }
        guard publication.rows.map(\.line) == evidence.rows else {
            throw .evidence("the evidence's PIN lines are not the ones publish run \(run) carries")
        }
        let adopted = (
            pin: pin.pinning(publication.revision),
            ledger: ledger.appending(publication.rows)
        )
        let verified = try Institute.Planner.Pin(text: adopted.pin)
        guard verified.revision == publication.revision else {
            throw .evidence("the pinned file does not pin \(publication.revision)")
        }
        _ = try Institute.Planner.Contract.verify(
            pin: verified,
            ledger: Institute.Planner.Ledger(text: adopted.ledger),
            release: release
        )
        self.revision = publication.revision
        self.run = run
        self.pin = adopted.pin
        self.ledger = adopted.ledger
        self.message = """
            Adopt planner \(publication.revision) from publish run \(run)

            Pin swift-institute/institute-application \(publication.revision) and append
            the rows publish-planner run \(run) published to .institute-ci-planner.

            Canary verdict \(evidence.verdict.rawValue), candidate against current \
            \(evidence.current?.row ?? "(none)"):
            \(evidence.summary.map { "- \($0)" }.joined(separator: "\n"))
            """
    }
}
