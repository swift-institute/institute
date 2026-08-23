import struct Swift.String
public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard
public import Institute_CI_Inventory

extension Institute.CI.Validation {
    /// `[CI-ANCHOR-001]` — the trust anchor's shipped block equals what
    /// its recorded inputs regenerate.
    ///
    /// The trust anchor pins the CI source repositories a workflow
    /// revision may execute (the ratified Q3 design,
    /// swift-institute/.github#461). Those pins are *generated*: measured
    /// from the source repositories and written into the workflow by the
    /// emitter that owns them,
    /// `Institute.CI.Inventory.Anchor`. Nothing about
    /// a 40-hex string in a YAML file says where it came from, though, so
    /// "generated" survives only as long as something re-derives it and
    /// compares. That is this rule, and it is the same shape as
    /// `SchemaCorrespondence`: two artifacts that must agree, checked by
    /// regenerating one from its inputs rather than by inspecting either.
    ///
    /// **What a finding here means.** Either a pin was hand-edited in the
    /// workflow — which is the failure the whole design exists to catch,
    /// since a typed pin is a floating ref that merely looks fixed — or
    /// the recorded inputs advanced and the workflow was not regenerated.
    /// Those are opposite causes with the same remedy: regenerate.
    ///
    /// **Applicability, and why absence is not a finding.** A repository
    /// with no recorded manifest claims no trust anchor, and this rule
    /// returns nothing for it. That is a deliberate, narrow exemption:
    /// the rule runs fleet-wide, where the overwhelming majority of
    /// repositories are consumers that never pin CI sources, and a rule
    /// that failed all of them would be turned off within the day. It is
    /// safe *because it is the manifest that is absent* — a repository
    /// that records an anchor is held to it completely, and every
    /// uncertainty from that point on is a finding rather than a pass: a
    /// manifest that cannot be read, a workflow that is not there, a
    /// workflow that will not parse, a step that is missing, a step that
    /// differs, and a checkout that does not precede its own identity
    /// check.
    ///
    /// The last of those is not pedantry. The identity check reads what
    /// git actually placed in the workspace; run before its checkout it
    /// reads a previous job's tree or nothing at all, and reports success
    /// either way.
    public struct Anchor: Validator {
        public let rules: [Rule] = ["CI-ANCHOR-001"]

        /// No retired counterpart: the cross-repository anchor has no
        /// pre-Swift implementation. The arrangement it replaces was an
        /// in-repository checkout at `job.workflow_sha`, which needed no
        /// script because it needed no pin.
        /// Where the recorded generator inputs live, by default.
        public static let manifestPath = ".github/trust-anchor.json"

        /// The workflow the anchor is emitted into, by default.
        public static let workflowPath = ".github/workflows/swift-ci.yml"

        public let manifestFile: String?
        public let workflowFile: String?

        public init(manifestFile: String? = nil, workflowFile: String? = nil) {
            self.manifestFile = manifestFile
            self.workflowFile = workflowFile
        }

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            let manifestRelative = manifestFile ?? Self.manifestPath
            let workflowRelative = workflowFile ?? Self.workflowPath

            // Absent manifest: this repository claims no anchor. Every
            // other unknown below is a finding.
            guard let manifestText = try subject.text(at: manifestRelative) else { return [] }

            let anchor: Institute.CI.Inventory.Anchor
            do throws(Institute.CI.Inventory.Error) {
                anchor = try .init(manifest: manifestText)
            } catch {
                return [finding(subject, "\(manifestRelative): \(error.message)")]
            }

            guard let workflowText = try subject.text(at: workflowRelative) else {
                return [
                    finding(
                        subject,
                        "\(manifestRelative) records a trust anchor over "
                            + "\(anchor.sources.count) source repositor"
                            + (anchor.sources.count == 1 ? "y" : "ies")
                            + ", but \(workflowRelative) does not exist -- the anchor "
                            + "has nothing to anchor."
                    )
                ]
            }

            let document: Institute.CI.Workflow.Document
            do throws(Institute.CI.Workflow.YAML.Error) {
                document = try .init(name: Self.name(of: workflowRelative), text: workflowText)
            } catch {
                return [
                    finding(
                        subject,
                        "\(workflowRelative): YAML parse failed: \(error.message) -- a "
                            + "workflow that cannot be read cannot be shown to carry its "
                            + "pins."
                    )
                ]
            }

            return Self.problems(regenerating: anchor, over: document, workflow: workflowRelative)
                .map { finding(subject, $0) }
        }

        private func finding(_ subject: Subject, _ message: String) -> Finding {
            Finding(repository: subject.repository, rule: rules[0], message: message)
        }

        private static func name(of path: String) -> String {
            path.split(separator: "/").last.map(String.init) ?? path
        }
    }
}

extension Institute.CI.Validation.Anchor {
    /// Every way the shipped workflow fails to be what the anchor
    /// regenerates.
    ///
    /// Reported per source rather than as one whole-block comparison. A
    /// single "the generated block does not match" tells a maintainer
    /// nothing about which of three pins moved, and the remedy differs by
    /// cause even though the command does not.
    static func problems(
        regenerating anchor: Institute.CI.Inventory.Anchor,
        over document: Institute.CI.Workflow.Document,
        workflow: String
    ) -> [String] {
        var problems: [String] = []
        for source in anchor.sources {
            let checkoutName = Institute.CI.Inventory.Anchor
                .checkoutName(of: source)
            let identityName = Institute.CI.Inventory.Anchor
                .identityName(of: source)
            let checkout = located(checkoutName, in: document)
            let identity = located(identityName, in: document)

            switch (checkout, identity) {
            case (nil, nil):
                problems.append(
                    "\(workflow) carries neither generated step for pinned source "
                        + "`\(source.repository)` (expected `\(checkoutName)` and "
                        + "`\(identityName)`). Regenerate the trust-anchor block; do not "
                        + "author it."
                )
                continue

            case (nil, .some):
                problems.append(
                    "\(workflow) carries the identity check for `\(source.repository)` "
                        + "but not its pinned checkout `\(checkoutName)` -- the check would "
                        + "read whatever else is in the workspace."
                )
                continue

            case (.some, nil):
                problems.append(
                    "\(workflow) checks out `\(source.repository)` at a pin but carries no "
                        + "`\(identityName)` step -- the fetched commit and tree are then "
                        + "never verified, and the pin is trusted on the fetcher's word "
                        + "alone."
                )
                continue

            case (.some(let checkout), .some(let identity)):
                if checkout.job != identity.job {
                    problems.append(
                        "\(workflow) checks out `\(source.repository)` in job "
                            + "`\(checkout.job)` but verifies it in job `\(identity.job)` -- "
                            + "each job gets its own workspace, so the check runs against a "
                            + "tree this pin never wrote."
                    )
                } else if identity.index < checkout.index {
                    problems.append(
                        "\(workflow) runs `\(identityName)` before `\(checkoutName)` in job "
                            + "`\(checkout.job)` -- the identity check would report on a "
                            + "workspace the pinned checkout has not written yet."
                    )
                }
                problems += difference(
                    shipped: checkout.node,
                    regenerated: anchor.checkoutStep(for: source),
                    step: checkoutName,
                    workflow: workflow
                )
                problems += difference(
                    shipped: identity.node,
                    regenerated: anchor.identityStep(for: source),
                    step: identityName,
                    workflow: workflow
                )
            }
        }
        return problems
    }

    /// One shipped step, and where it sits.
    struct Placement {
        let job: String
        let index: Int
        let node: Institute.CI.Workflow.YAML.Node
    }

    /// The step a generated name identifies. The name is the join key
    /// because it is itself generated from the repository coordinate — a
    /// maintainer cannot rename a step into or out of correspondence
    /// without the rename showing up as a missing step.
    ///
    /// First match wins, and a second step with the same generated name
    /// is reported by the comparison rather than silently preferred: the
    /// emitter cannot produce two, so a duplicate is hand-authored.
    static func located(
        _ name: String,
        in document: Institute.CI.Workflow.Document
    ) -> Placement? {
        for job in document.jobs {
            for (index, step) in job.steps.enumerated() where step["name"]?.text == name {
                return Placement(job: job.name, index: index, node: .mapping(step))
            }
        }
        return nil
    }

    /// How a shipped step differs from its regeneration, if it does.
    static func difference(
        shipped: Institute.CI.Workflow.YAML.Node,
        regenerated: Institute.CI.Workflow.YAML.Node,
        step: String,
        workflow: String
    ) -> [String] {
        guard shipped != regenerated else { return [] }
        let shippedJSON = Institute.CI.Workflow.YAML.Canonical.json(shipped)
        let regeneratedJSON = Institute.CI.Workflow.YAML.Canonical.json(regenerated)
        guard shippedJSON != regeneratedJSON else {
            return [
                "\(workflow) step `\(step)` carries the generated keys in a different "
                    + "order than the emitter writes them. Regenerate rather than "
                    + "reordering: a hand-tidied generated block is one a later "
                    + "regeneration will silently revert."
            ]
        }
        return [
            "\(workflow) step `\(step)` is not what the recorded trust-anchor inputs "
                + "regenerate. shipped=\(shippedJSON) regenerated=\(regeneratedJSON) -- "
                + "either the pin was hand-edited in the workflow, or the recorded "
                + "inputs advanced and the block was not regenerated."
        ]
    }
}
