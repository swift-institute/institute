public import Institute_Doctor
public import Institute_Model
public import Institute_Pages

extension Institute.Conversion {
    /// One repository's mechanically derived protocol-§1 arm assignment.
    ///
    /// Never serialized: the receipt carries no arm field by design (issue
    /// #83 Part 2). A reviewer reproduces every entry from ``Receipt/pages``
    /// alone with `git cat-file blob <digest>` and nothing else — this type
    /// exists so Swift callers (the canary executor included) get the same
    /// derivation without re-deriving it themselves.
    public struct EvaluationCohortEntry: Equatable, Sendable {
        public let coordinate: Institute.Repository.Key
        public let armLegacyBlob: Swift.String
        public let armConvertedBlob: Swift.String?
        public let excluded: Swift.Bool
    }
}

extension Institute.Conversion.Receipt {
    /// The mechanical realisation of protocol §1: one entry per cohort
    /// repository whose page `kind` is `readme`, with the sole exclusion
    /// rule applied — the two digests are equal, or the post-conversion
    /// digest does not yet exist.
    public var evaluationCohort: [Institute.Conversion.EvaluationCohortEntry] {
        pages
            .filter { $0.kind == .readme }
            .sorted(by: Institute.Conversion.Page.precedes)
            .map { page in
                let excluded =
                    page.postConversionBlob == nil
                    || page.postConversionBlob == page.preConversionBlob
                return Institute.Conversion.EvaluationCohortEntry(
                    coordinate: page.coordinate,
                    armLegacyBlob: page.preConversionBlob,
                    armConvertedBlob: page.postConversionBlob,
                    excluded: excluded
                )
            }
    }
}
