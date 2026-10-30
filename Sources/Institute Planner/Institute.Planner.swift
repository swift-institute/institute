public import Institute_Model

extension Institute {
    /// The fleet CI planner's release chain: a `publish-planner` run puts
    /// digest-named planner assets on swift-institute/institute's
    /// `ci-binaries` release; swift-institute/.github adopts one by
    /// appending its PIN lines to `.institute-ci-planner` and pinning its
    /// revision in `.institute-ci-pin`.
    ///
    /// This namespace owns the contract between the two — the shape of
    /// every line, which assets a publish consists of, which rows are
    /// admissible — and the two coordinator verbs over it: `canary`, which
    /// runs a published candidate against the current planner, and
    /// `adopt`, which records an adoptable candidate as one local commit.
    /// The contract is the one
    /// `.github/actions/institute-ci/verify-planner-pins.sh` states; the
    /// two must refuse the same inputs.
    public enum Planner {}
}

extension Institute.Planner {
    /// The repository whose `ci-binaries` release carries the planner.
    public static let publisher = "swift-institute/institute"

    /// The release every planner asset is published on.
    public static let tag = "ci-binaries"

    /// The repository that adopts a planner and reads its pin live.
    public static let consumer = "swift-institute/.github"

    /// Whether `text` is exactly `count` lowercase hexadecimal characters.
    static func isHex(_ text: some StringProtocol, count: Swift.Int) -> Swift.Bool {
        text.utf8.count == count
            && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    /// The meaningful lines of a pin or planner file: neither blank nor a
    /// `#` comment, after leading whitespace.
    static func entries(_ text: Swift.String) -> [Swift.Substring] {
        text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let content = line.drop { $0 == " " || $0 == "\t" }
            return !content.isEmpty && content.first != "#"
        }
    }
}
