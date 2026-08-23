extension Repository.Policy.Uniformity.Wave {
    /// REST pricing for one uniformity subject across preflight, apply,
    /// and closure under one organization's installation pool.
    ///
    /// Audited worst path, anchored on the caller wave's measured
    /// baseline (its preflight measured exactly 8; uniformity reads four
    /// shape files where the caller wave read one caller):
    /// - **preflight**: ≤ 11 requests (2× repository, 2× ref, rulesets
    ///   list, ruleset read, manifest, 4× shape file).
    /// - **apply**: ≤ 27 requests (repository, head, manifest, 4× shape,
    ///   blob, ruleset list/read, window open replace+read, re-guarded
    ///   head and shape, parent commit read, tree, commit, guarded head,
    ///   ref move, converged-head read, 4× shape verification, bypass
    ///   close replace+read, closed verification read).
    /// - **close**: ≤ 11 requests (repository, head, manifest, 4× shape,
    ///   rulesets list, ruleset read, bypass close, final read).
    /// - **retry budget**: the bounded ruleset and converged-head loops,
    ///   ≤ 9 further requests.
    ///
    /// 11 + 27 + 11 + 9 = 58. The largest current organization (206
    /// subjects) prices at 58 × 206 + 160 = 12,108, inside GitHub's hard
    /// 12,500/h installation cap, and the gate still refuses honestly
    /// whenever the pool is genuinely short (small installations start
    /// at 5,000).
    public enum Capacity {
        public static let subjectRequests = 58

        /// Fixed per-organization overhead: capacity probe, attestation,
        /// artifact bookkeeping, and margin for occasional 5xx retries
        /// outside the per-subject loops.
        public static let organizationOverhead = 160

        /// The wave's REST requirement for one organization, owned here
        /// so no policy arithmetic lives in workflow shell.
        public static func requirement(subjects: Int) -> Int {
            subjects * Self.subjectRequests + Self.organizationOverhead
        }
    }
}
