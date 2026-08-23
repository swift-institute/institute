extension Repository.Policy.Caller.Wave.Capacity {
    /// REST requests one wave subject may spend across all three phases
    /// under one organization's installation pool in one hour window.
    ///
    /// Calibrated, not guessed (wave run 31817391995 follow-up):
    /// - **preflight, measured**: exactly 8 requests per subject —
    ///   counted through an instrumented `GITHUB_API_URL` endpoint over
    ///   live zero-mutation preflights (2× repository, 2× ref, 1×
    ///   rulesets list, 1× ruleset read, 1× manifest, 1× caller).
    /// - **apply, audited worst path**: ≤ 20 requests (blob, commit,
    ///   ref move, verification reads, ruleset open/close and
    ///   read-backs).
    /// - **close, audited**: ≤ 8 requests.
    /// - **retry budget**: the ruleset transition and bypass-closure
    ///   loops retry up to 4 attempts of replace+read, ≤ 12 further
    ///   requests.
    ///
    /// 8 + 20 + 8 + 12 = 48. The former host-side `64 × subjects + 128`
    /// shell estimate demanded 13,312 for a 206-subject organization and
    /// refused against GitHub's hard 12,500/h installation cap even
    /// though the wave cannot spend that much; 48 × 206 + 160 = 10,048
    /// fits, and the gate still refuses honestly whenever the pool is
    /// genuinely short (small installations start at 5,000).
    public static let subjectRequests = 48

    /// Fixed per-organization overhead: capacity probe, attestation,
    /// artifact bookkeeping, and margin for the occasional 5xx retry
    /// outside the per-subject loops.
    public static let organizationOverhead = 160

    /// The wave's REST requirement for one organization, owned here so
    /// no policy arithmetic lives in workflow shell.
    public static func requirement(subjects: Int) -> Int {
        subjects * Self.subjectRequests + Self.organizationOverhead
    }
}

extension Repository.Policy.Caller.Wave {
    public struct Capacity: Codable, Sendable, Equatable {
        public let remaining: Int
        public let required: Int
        public let resetAt: Int
        public let accepted: Bool

        public init(remaining: Int, required: Int, resetAt: Int) {
            self.remaining = remaining
            self.required = required
            self.resetAt = resetAt
            self.accepted = remaining >= required
        }
    }
}
