public import Institute_Model

extension Institute.Version {
    /// A sequence of development versions: every tag on the line is the
    /// line's stem followed by one decimal ordinal, and the next tag is the
    /// highest ordinal on the line plus one, never below the floor.
    ///
    /// The line is a value, not a convention, so moving `main` from
    /// `0.0.N` to pre-release tags after a real release is a new line, not
    /// a new algorithm.
    public enum Line: Swift.Hashable, Swift.Sendable {
        /// `major.minor.N`, plain SemVer without a pre-release suffix.
        case patch(major: Swift.Int, minor: Swift.Int, floor: Swift.Int)
        /// `major.minor.patch-identifier.N`, a SemVer pre-release of the
        /// version that follows a real release.
        case prerelease(
            major: Swift.Int,
            minor: Swift.Int,
            patch: Swift.Int,
            identifier: Swift.String,
            floor: Swift.Int
        )
    }
}

extension Institute.Version.Line {
    /// The line every Institute package is on: `0.0.N`, starting at
    /// `0.0.100`, above every `0.0.x` tag that existed before the line.
    public static let development: Self = .patch(major: 0, minor: 0, floor: 100)

    /// Everything a tag on the line carries before its ordinal; also the
    /// prefix the line's tags are listed by.
    public var stem: Swift.String {
        switch self {
        case .patch(let major, let minor, _):
            "\(major).\(minor)."
        case .prerelease(let major, let minor, let patch, let identifier, _):
            "\(major).\(minor).\(patch)-\(identifier)."
        }
    }

    /// The lowest ordinal the line hands out.
    public var floor: Swift.Int {
        switch self {
        case .patch(_, _, let floor): floor
        case .prerelease(_, _, _, _, let floor): floor
        }
    }

    /// The tag of `ordinal` on the line.
    public func tag(_ ordinal: Swift.Int) -> Swift.String {
        stem + "\(ordinal)"
    }

    /// The ordinal of `tag` when `tag` is on the line, and nil for any
    /// other tag: another line, a non-numeric or zero-padded ordinal, a
    /// build-metadata suffix, or a name such as `ci-binaries`.
    public func ordinal(of tag: Swift.String) -> Swift.Int? {
        guard tag.hasPrefix(stem) else { return nil }
        let digits = tag.dropFirst(stem.count)
        guard
            !digits.isEmpty,
            digits.allSatisfy({ $0.isASCII && $0.isNumber }),
            digits == "0" || digits.first != "0",
            let ordinal = Swift.Int(digits)
        else { return nil }
        return ordinal
    }

    /// The ordinal after `ordinals`: one above the highest, and never
    /// below the floor.
    public func next(after ordinals: some Swift.Sequence<Swift.Int>) -> Swift.Int {
        Swift.max(floor, (ordinals.max() ?? floor - 1) + 1)
    }
}
