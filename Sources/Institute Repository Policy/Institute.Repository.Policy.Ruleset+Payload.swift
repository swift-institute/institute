public import Institute_Model
public import Byte
public import JSON

// The Institute protected-main branch ruleset contracts, converged by
// `sync-metadata`'s `rulesets` job and read back for drift detection.
//
// Two independent dimensions select the applicable payload
// (swift-institute/.github#276 Task 3-01):
//
// - **Class**: `package` vs `control-plane` vs a declared override.
//   The `protectedMainPayload` family covers `package`;
//   `protectedMainControlPayload` covers `control-plane` and never carries
//   a `required_status_checks` rule at all — its absence is fail-closed
//   enforced by the validator, not merely unchecked.
// - **Visibility**: a `package`-class repository's required-check context
//   depends on whether it is public or private, read live from GitHub and
//   never defaulted when unreadable. A public package requires exactly
//   `ci / matrix / ci-ok`; a private package requires exactly
//   `verification / workspace`.
//
// Break-glass: in a genuine emergency, an organization admin may delete
// the "Institute protected main" ruleset directly on the affected
// repository. This bypass requires a durable receipt comment on the
// owning issue; once over, the ruleset is re-applied by dispatch, never
// left deleted or hand-recreated.
extension Institute.Repository.Policy.Ruleset {
    public struct Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        public let description: String

        public init(_ description: String) {
            self.description = description
        }
    }

    /// The target public contract: exactly `ci / matrix / ci-ok`.
    public static func protectedMainPayload(from bytes: [Byte]) throws(Error) -> [Byte] {
        try protectedMainPackagePayload(
            from: bytes,
            requiredContexts: ["ci / matrix / ci-ok"]
        )
    }

    /// The private contract: exactly `verification / workspace`, the
    /// trusted control-plane receipt (swift-institute/.github#253). No
    /// compatibility variant: no producer preceded it.
    public static func protectedMainPrivatePayload(
        from bytes: [Byte]
    ) throws(Error) -> [Byte] {
        try protectedMainPackagePayload(
            from: bytes,
            requiredContexts: ["verification / workspace"]
        )
    }

    /// Shared package-class validator parameterized by the exact set of
    /// required contexts. `requiredContexts` is the Swift-side equality
    /// guard: it must match the JSON policy file's own
    /// `required_status_checks` contexts exactly (same cardinality, same
    /// set, no duplicates) or the payload is rejected — a one-sided
    /// Swift-only or JSON-only edit fails this guard.
    private static func protectedMainPackagePayload(
        from bytes: [Byte],
        requiredContexts: Set<String>
    ) throws(Error) -> [Byte] {
        let (object, rules) = try identity(
            from: bytes,
            expectedName: "Institute protected main"
        )
        guard
            Set(rules.compactMap { Swift.String($0["type"] as JSON?) }) == [
                "deletion", "non_fast_forward", "pull_request", "required_status_checks",
            ]
        else {
            throw Error(
                "protected-main ruleset rules differ from the Institute contract"
            )
        }
        try validatePullRequestRule(rules)
        guard
            let checks = rules.first(where: {
                Swift.String($0["type"] as JSON?) == "required_status_checks"
            })?["parameters"],
            Swift.Bool(checks["strict_required_status_checks_policy"]) == true,
            Swift.Bool(checks["do_not_enforce_on_create"]) == false,
            let required = checks["required_status_checks"].array,
            required.count == requiredContexts.count,
            Set(required.compactMap { Swift.String($0["context"] as JSON?) })
                == requiredContexts
        else {
            throw Error(
                "protected-main status-check transaction differs from the Institute contract"
            )
        }
        return serialized(object)
    }

    /// The control-plane variant: identical protections minus the
    /// required-status-check rule, since control-plane repositories emit
    /// neither required context — visibility is irrelevant to this class.
    /// A payload carrying a fourth rule of any type (including a smuggled
    /// `required_status_checks`) fails closed.
    public static func protectedMainControlPayload(
        from bytes: [Byte]
    ) throws(Error) -> [Byte] {
        let (object, rules) = try identity(
            from: bytes,
            expectedName: "Institute protected main (control)"
        )
        guard
            Set(rules.compactMap { Swift.String($0["type"] as JSON?) }) == [
                "deletion", "non_fast_forward", "pull_request",
            ]
        else {
            throw Error(
                "protected-main control ruleset rules differ from the Institute contract"
            )
        }
        try validatePullRequestRule(rules)
        return serialized(object)
    }

    /// Shared identity checks both contract classes require: schema
    /// version, name/target/enforcement, no bypass actors, and the
    /// main-only ref-name condition. Returns the schema-stripped object
    /// together with its raw `rules` array for the caller's
    /// class-specific rule validation.
    private static func identity(
        from bytes: [Byte],
        expectedName: String
    ) throws(Error) -> (object: [String: JSON], rules: [JSON]) {
        let parsed: JSON
        do throws(JSON.Error) {
            parsed = try JSON.parse(bytes)
        } catch {
            throw Error("could not read the protected-main ruleset: \(error)")
        }
        guard var object = parsed.dictionary else {
            throw Error("protected-main ruleset must be a JSON object")
        }
        guard object.removeValue(forKey: "schemaVersion").flatMap(Swift.Int.init) == 1 else {
            throw Error("unsupported protected-main ruleset schema")
        }
        guard Swift.String(object["name"]) == expectedName,
            Swift.String(object["target"]) == "branch",
            Swift.String(object["enforcement"]) == "active"
        else {
            throw Error("protected-main ruleset identity is invalid")
        }
        guard let bypass = object["bypass_actors"]?.array else {
            throw Error("protected-main ruleset must declare bypass_actors")
        }
        // The R28.1 programme bypass window is retired with the
        // compatibility payload class. The standing contract is the only
        // lawful shape: no actor may bypass protected main.
        guard bypass.isEmpty else {
            throw Error("protected-main ruleset permits a bypass actor")
        }
        guard let conditions = object["conditions"],
            conditions.isObject,
            conditions["ref_name"].isObject,
            conditions["ref_name"]["include"] == ["refs/heads/main"],
            conditions["ref_name"]["exclude"] == []
        else {
            throw Error("protected-main ruleset must select only main")
        }
        guard let rules = object["rules"]?.array,
            rules.allSatisfy(\.isObject)
        else {
            throw Error(
                "protected-main ruleset rules differ from the Institute contract"
            )
        }
        return (object, rules)
    }

    /// The pull-request transaction both contract classes pin identically.
    ///
    /// Pre-release posture (ICI#35 adjudication 2026-08-14): no approval
    /// gate — one principal, zero external consumers. The release re-arm
    /// restores count 1 and last-push approval here and in the contract
    /// JSONs together.
    private static func validatePullRequestRule(
        _ rules: [JSON]
    ) throws(Error) {
        guard
            let review = rules.first(where: {
                Swift.String($0["type"] as JSON?) == "pull_request"
            })?["parameters"],
            review.isObject,
            Swift.Int(review["required_approving_review_count"]) == 0,
            Swift.Bool(review["dismiss_stale_reviews_on_push"]) == true,
            Swift.Bool(review["require_last_push_approval"]) == false,
            Swift.Bool(review["required_review_thread_resolution"]) == true,
            Swift.Bool(review["require_code_owner_review"]) == false,
            // GitHub server-canonicalizes these three fields onto every
            // pull_request rule even when the contract omits them, which
            // fails the fail-closed read-back comparison in
            // sync-metadata.yml's `rulesets` job. Pinning them here keeps
            // the contract, the applied ruleset, and its read-back in
            // exact correspondence, and keeps merge-method policy
            // (squash-only) an explicit, enforced fact rather than an
            // unpinned server default.
            review["allowed_merge_methods"] == ["squash"],
            review["required_reviewers"].array?.isEmpty == true,
            review["dismissal_restriction"].isObject,
            Swift.Bool(review["dismissal_restriction"]["enabled"]) == false,
            review["dismissal_restriction"]["allowed_actors"].array?.isEmpty == true
        else {
            throw Error(
                "protected-main pull-request transaction differs from the Institute contract"
            )
        }
    }

    private static func serialized(_ object: [String: JSON]) -> [Byte] {
        [Byte](
            utf8: JSON.object(object.map { ($0.key, $0.value) })
                .serialize(sortKeys: true)
        )
    }
}
