public import Institute_Model
public import Byte_Primitives
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    /// The uniformity-relevant shape of one repository at an exact head:
    /// the root `.gitignore` (with exact bytes) and the presence of each
    /// retired configuration file, keyed by blob so every mutation guard
    /// is an exact compare-and-set fact.
    public struct Shape: Sendable, Equatable {
        /// The paths this wave writes or deletes; nothing else changes.
        public static let gitignorePath = ".gitignore"
        public static let swiftlintPath = ".swiftlint.yml"
        public static let swiftFormatPath = ".swift-format"
        public static let dependabotPath = ".github/dependabot.yml"
        public static let deletionPaths = [swiftlintPath, swiftFormatPath, dependabotPath]

        public let gitignore: File?
        public let swiftlint: String?
        public let swiftFormat: String?
        public let dependabot: String?

        public init(
            gitignore: File?,
            swiftlint: String?,
            swiftFormat: String?,
            dependabot: String?
        ) {
            self.gitignore = gitignore
            self.swiftlint = swiftlint
            self.swiftFormat = swiftFormat
            self.dependabot = dependabot
        }

        /// The retired paths this exact shape still tracks — the
        /// deletion set of the forward commit.
        public var presentDeletions: [String] {
            var paths: [String] = []
            if swiftlint != nil { paths.append(Self.swiftlintPath) }
            if swiftFormat != nil { paths.append(Self.swiftFormatPath) }
            if dependabot != nil { paths.append(Self.dependabotPath) }
            return paths
        }

        /// Whether this shape already satisfies the ratified policy: the
        /// root `.gitignore` carries exactly the canonical bytes and all
        /// three retired files are absent. A terminal subject is
        /// re-receipted without mutation.
        public func terminal(payload: [Byte]) -> Bool {
            gitignore?.bytes == payload && presentDeletions.isEmpty
        }

        /// The exact facts one shape contributes to a population state
        /// digest: every blob identity, with absence recorded explicitly
        /// so present-and-absent states can never collide.
        public var digestComponents: [String] {
            [
                gitignore?.blob ?? "gitignore-absent",
                swiftlint ?? "swiftlint-absent",
                swiftFormat ?? "swift-format-absent",
                dependabot ?? "dependabot-absent",
            ]
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Shape: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "gitignore": value.gitignore.json,
            "swiftlint": value.swiftlint.json,
            "swiftFormat": value.swiftFormat.json,
            "dependabot": value.dependabot.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            gitignore: try Institute.Repository.Policy.Uniformity.Wave.File?(json: json["gitignore"]),
            swiftlint: try Swift.String?(json: json["swiftlint"]),
            swiftFormat: try Swift.String?(json: json["swiftFormat"]),
            dependabot: try Swift.String?(json: json["dependabot"])
        )
    }
}
