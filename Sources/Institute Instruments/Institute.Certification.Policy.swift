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

        public init(platforms: [Platform]) throws(Institute.Error) {
            guard !platforms.isEmpty else {
                throw .configuration("a certification policy requires at least one platform")
            }
            var seen = Set<Platform>()
            for platform in platforms {
                guard seen.insert(platform).inserted else {
                    throw .configuration("duplicate policy platform: \(platform.rawValue)")
                }
            }
            self.platforms = platforms.sorted { $0.rawValue < $1.rawValue }
        }

        public static func serialize(_ value: Self) -> JSON {
            ["platforms": value.platforms.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let platforms = object["platforms"] else { throw .missingKey("platforms") }
            do {
                return try Self(
                    platforms: [Institute.Certification.Platform](json: platforms)
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
        }
        return obligations.sorted(by: precedes)
    }
}
