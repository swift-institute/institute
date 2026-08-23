extension ContinuousIntegration {
    /// The verification tier (R1/R2 ruling 2026-07-20; 'lint' retired
    /// 2026-07-28 and refused rather than silently promoted).
    public enum Tier: String, Sendable, Equatable, CaseIterable {
        /// The fast path: quality gates and one release leg. Ordinary
        /// pushes and pull requests.
        case build
        /// The merge path: the whole gating platform contract. Reached by
        /// the integration ref, an explicit dispatch, or `[ci full]`.
        case full
        /// Everything the fleet can run, including legs whose cost or
        /// stability keeps them off every automatic path. Never reached by
        /// a ref or an event — only by asking for it, because a leg that
        /// runs on merge is not opt-in whatever it is labelled.
        case exhaustive
    }
}
