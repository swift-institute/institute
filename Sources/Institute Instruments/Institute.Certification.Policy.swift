public import Institute_Model
public import JSON

extension Institute.Certification {
    /// The explicit execution policy a certification runs under: which
    /// platforms every package member owes its builds and tests on.
    ///
    /// The policy is an input recorded ahead of execution — obligations
    /// derive from snapshot × policy, so nothing about coverage is decided
    /// by where a run happened to execute.
    public struct Policy: Equatable, Sendable, JSON.Serializable {
        public let platforms: [Platform]

        /// The quality obligations every package member owes, executed
        /// once per member on the designated quality platform (`linux`) —
        /// platform-independent gates whose omission must still be a
        /// visible uncovered obligation (.github#269).
        public let quality: [Obligation.Kind]

        /// Which exception reasons this policy admits as lawful coverage.
        ///
        /// Waiver admissibility is a property of the exact promoted
        /// policy, never of a certificate constructor: by default only
        /// `notApplicable` is admissible, so a known defect can never
        /// turn green unless the policy that judges the certificate
        /// explicitly authorizes that reason (.github#627 promotion).
        public let admissible: [Exception.Reason]

        public init(
            platforms: [Platform],
            quality: [Obligation.Kind] = [.lint, .format],
            admissible: [Exception.Reason] = [.notApplicable]
        ) throws(Institute.Error) {
            guard !platforms.isEmpty else {
                throw .configuration("a certification policy requires at least one platform")
            }
            var seen = Set<Platform>()
            for platform in platforms {
                guard seen.insert(platform).inserted else {
                    throw .configuration("duplicate policy platform: \(platform.rawValue)")
                }
            }
            for kind in quality {
                guard kind == .lint || kind == .format else {
                    throw .configuration(
                        "\(kind.rawValue) is a package execution obligation, not a quality gate"
                    )
                }
            }
            self.platforms = platforms.sorted { $0.rawValue < $1.rawValue }
            self.quality = Set(quality).sorted { $0.rawValue < $1.rawValue }
            self.admissible = Set(admissible).sorted { $0.rawValue < $1.rawValue }
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "platforms": value.platforms.json,
                "quality": value.quality.json,
                "admissible": value.admissible.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let platforms = object["platforms"] else { throw .missingKey("platforms") }
            guard let quality = object["quality"] else { throw .missingKey("quality") }
            guard let admissible = object["admissible"] else { throw .missingKey("admissible") }
            do {
                return try Self(
                    platforms: [Institute.Certification.Platform](json: platforms),
                    quality: [Institute.Certification.Obligation.Kind](json: quality),
                    admissible: [Institute.Certification.Exception.Reason](json: admissible)
                )
            } catch let error as JSON.Error {
                throw error
            } catch {
                throw .typeMismatch(
                    expected: "structurally valid policy",
                    got: Swift.String(describing: error)
                )
            }
        }
    }
}

extension Institute.Certification.Obligation {
    /// Derive the complete required obligation set for one snapshot under
    /// one policy: every package member owes one build and one test
    /// execution per policy platform. Control-plane members carry no
    /// package obligations — their requirement class is typed on the
    /// member itself, not silently omitted.
    ///
    /// Deterministic: the same snapshot and policy always produce the same
    /// ordered obligation list.
    public static func derive(
        from snapshot: Institute.Certification.Snapshot,
        policy: Institute.Certification.Policy
    ) -> [Self] {
        var obligations = [Self]()
        for member in snapshot.members {
            guard case .package = member.kind else { continue }
            for platform in policy.platforms {
                obligations.append(.init(key: member.key, kind: .build, platform: platform))
                obligations.append(.init(key: member.key, kind: .test, platform: platform))
            }
            for kind in policy.quality {
                obligations.append(.init(key: member.key, kind: kind, platform: .linux))
            }
        }
        return obligations.sorted(by: precedes)
    }
}
