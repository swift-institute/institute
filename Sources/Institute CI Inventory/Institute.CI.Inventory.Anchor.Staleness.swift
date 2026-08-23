public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Inventory.Anchor {
    /// How far each pin has fallen behind its source repository's `main`.
    ///
    /// **Advisory, permanently.** A pin being behind `main` is not a
    /// defect: that is what a pin *is*. The whole value of an anchor is
    /// that the workflow executes a revision someone chose, and a gate
    /// that failed until every pin equalled the tip would convert the
    /// anchor back into a floating ref by making any other state
    /// unshippable.
    ///
    /// Advisory is enforced structurally rather than promised. This type
    /// produces no `Finding`, has no `Rule`, and is registered in no
    /// validator registry — the finding channel is blocking by
    /// construction, so the only durable way to keep a report advisory is
    /// to keep it out of that channel entirely. `isBlocking` is a
    /// constant a test can read, not a mode.
    public struct Staleness: Sendable, Equatable {
        /// Never true. See above.
        public static let isBlocking = false

        public let rows: [Row]

        public init(rows: [Row]) {
            self.rows = rows
        }

        /// The report for an anchor, given whatever was observed.
        ///
        /// Row order follows the anchor's own source order, so the report
        /// reads the same on every run regardless of the order
        /// observations arrived in. An observation naming a repository
        /// the anchor does not pin contributes nothing — there is no pin
        /// for it to be a distance from.
        public init(
            anchor: Institute.CI.Inventory.Anchor,
            observed: [Observation]
        ) {
            let byRepository = Dictionary(
                observed.map { ($0.repository, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            self.rows = anchor.sources.map { source in
                let observation = byRepository[source.repository]
                return Row(
                    repository: source.repository,
                    pinned: source.commit,
                    head: observation?.head,
                    distance: observation?.distance
                )
            }
        }

        /// The sources whose pin is not the observed tip. Unmeasured
        /// sources are not here — they are in `unmeasured`.
        public var behind: [Row] { rows.filter { $0.isMeasured && !$0.isCurrent } }

        /// The sources whose `main` nobody looked at.
        public var unmeasured: [Row] { rows.filter { !$0.isMeasured } }

        public var node: Institute.CI.Workflow.YAML.Node {
            .mapping(
                .init([
                    (.text("advisory"), .boolean(true)),
                    (.text("blocking"), .boolean(Self.isBlocking)),
                    (.text("rows"), .sequence(rows.map(\.node))),
                    (.text("behind"), .integer(behind.count)),
                    (.text("unmeasured"), .integer(unmeasured.count)),
                ])
            )
        }

        public var canonicalJSON: String {
            Institute.CI.Workflow.YAML.Canonical.json(node)
        }
    }
}
