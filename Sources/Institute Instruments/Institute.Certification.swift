public import Institute_Model

extension Institute {
    /// The exact-snapshot fleet-certification vocabulary.
    ///
    /// Fleet green is a property of one immutable exact snapshot — a map
    /// from every admitted member to one exact commit revision, plus typed
    /// exclusions — not the conjunction of independently timed
    /// per-repository runs (`swift-institute/.github#600`, ruling of
    /// 2026-08-18). ``Snapshot`` is that input; the certification laws it
    /// serves are recorded on `swift-institute/institute-application#210`.
    ///
    /// This namespace owns certification *data* semantics. Composition and
    /// execution remain with their incumbent owners — ``Coherence`` for the
    /// composed-root instrument and its canonical receipt seam,
    /// `Institute.Composed` for graph rendering. Nothing here duplicates a
    /// receipt schema: a certificate references `Coherence.Receipt` digests
    /// as component evidence.
    public enum Certification {}
}
