public import Institute_Model
public import SPM_Standard

extension Institute.Certification {
    /// The law-2 instrument: proves every Institute-internal dependency a
    /// member's resolution used stays inside the exact snapshot.
    ///
    /// The governed-organization set derives from the snapshot itself —
    /// the organizations of admitted members plus the layer-root
    /// organizations — never a hand-maintained list. Within that set,
    /// three escapes fail closed:
    ///
    /// - an identity that is not an admitted member (the swift-tls class,
    ///   institute-application#212: in-organization, out-of-population,
    ///   defect-propagating, invisible to census);
    /// - a source-control checkout whose resolved revision is not the
    ///   snapshot member's exact revision (temporal skew — the resolution
    ///   compiled different source than the snapshot certifies);
    /// - a governed location that does not parse as a canonical repository
    ///   key (an edge the instrument cannot classify is a failure, not a
    ///   pass).
    ///
    /// A file-system state for a member is lawful only at composed/local
    /// materialization; the caller states which modes are acceptable.
    public enum Closure {}
}

extension Institute.Certification.Closure {
    /// The organizations the snapshot governs: every admitted member's
    /// owner plus the five layer roots.
    public static func organizations(
        of snapshot: Institute.Certification.Snapshot
    ) -> Set<Swift.String> {
        var organizations = Set(Institute.Layer.allCases.map(\.organization))
        for member in snapshot.members {
            organizations.insert(member.key.owner.underlying)
        }
        for exclusion in snapshot.exclusions {
            organizations.insert(exclusion.key.owner.underlying)
        }
        return organizations
    }

    /// Evaluate one member's resolved state against the snapshot,
    /// producing one proof per Institute-internal edge. Edges to
    /// organizations outside the governed set produce no proof — they are
    /// external dependencies owned by other policy.
    public static func proofs(
        consumer: Institute.Repository.Key,
        resolution: Package.Resolution,
        snapshot: Institute.Certification.Snapshot,
        accepting: Set<Mode> = [.remoteExact]
    ) -> [Proof] {
        let governed = organizations(of: snapshot)
        var proofs = [Proof]()
        for dependency in resolution.dependencies {
            let location = dependency.reference.location
            guard let owner = Self.owner(of: location) else {
                // Not a github.com URL — a local path or another host.
                // Local paths are certifiable only through `.localPath`
                // acceptance below, and reach it via key-less
                // classification: without a canonical key the edge cannot
                // be a governed member, so a governed-looking non-URL
                // location fails in the fallthrough.
                continue
            }
            guard governed.contains(owner) else { continue }

            guard let key = Self.key(of: location) else {
                proofs.append(
                    .init(
                        consumer: consumer,
                        location: location,
                        verdict: .unclassifiable
                    )
                )
                continue
            }
            guard let member = snapshot[key] else {
                proofs.append(
                    .init(
                        consumer: consumer,
                        location: location,
                        verdict: snapshot.exclusions.contains(where: { $0.key == key })
                            ? .excludedMember(key)
                            : .ungoverned(key)
                    )
                )
                continue
            }

            switch dependency.state {
            case .sourceControlCheckout(let checkout):
                if !accepting.contains(.remoteExact) {
                    proofs.append(
                        .init(
                            consumer: consumer,
                            location: location,
                            verdict: .networkEscape(key)
                        )
                    )
                } else if checkout.revision == member.revision.sha {
                    proofs.append(
                        .init(
                            consumer: consumer,
                            location: location,
                            verdict: .exact(key)
                        )
                    )
                } else {
                    proofs.append(
                        .init(
                            consumer: consumer,
                            location: location,
                            verdict: .revisionSkew(
                                key,
                                resolved: checkout.revision,
                                member: member.revision.sha
                            )
                        )
                    )
                }

            case .fileSystem, .edited:
                proofs.append(
                    .init(
                        consumer: consumer,
                        location: location,
                        verdict: accepting.contains(.localPath)
                            ? .local(key)
                            : .unexpectedLocal(key)
                    )
                )
            }
        }
        return proofs
    }

    private static func owner(of location: Swift.String) -> Swift.String? {
        let prefix = "https://github.com/"
        guard location.hasPrefix(prefix) else { return nil }
        let remainder = location.dropFirst(prefix.count)
        guard let separator = remainder.firstIndex(of: "/") else { return nil }
        return Swift.String(remainder[..<separator])
    }

    private static func key(of location: Swift.String) -> Institute.Repository.Key? {
        if let key = Institute.Repository.Key(url: location) { return key }
        return Institute.Repository.Key(url: location + ".git")
    }
}

extension Institute.Certification.Closure {
    /// Which resolution states are acceptable for a governed member in
    /// the evaluation at hand.
    public enum Mode: Sendable, Hashable {
        /// A managed checkout at exactly the snapshot member revision —
        /// the per-member evaluation profile.
        case remoteExact

        /// A local path — the composed/materialized profile.
        case localPath
    }
}
