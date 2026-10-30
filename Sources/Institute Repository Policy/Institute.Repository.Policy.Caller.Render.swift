public import Institute_Model

extension Institute.Repository.Policy.Caller {
    /// The generated caller's bytes.
    ///
    /// This renderer is a closed projection: it emits only admitted
    /// declarations (triggers/filters, root read ceiling, one concurrency
    /// declaration, one reusable call). A declaration it cannot represent is
    /// STOP-F3-YAML, never a hand-authored escape.
    public enum Render {
        /// The terminal generated caller. Package identity and desired-state
        /// differences are resolved by the central policy owner after the
        /// reusable hop, so every package receives these exact bytes.
        ///
        /// The `merge_group` trigger is declared ahead of any merge queue
        /// existing (D2, #35): a trigger for an event that is never
        /// delivered schedules nothing, so the declaration is inert until
        /// a queue is enabled — at which point the fleet already listens.
        public static var terminal: String {
            [
                "name: CI",
                "",
                "on:",
                "  push:",
                "    branches:",
                "      - main",
                "  pull_request:",
                "    branches:",
                "      - main",
                "  merge_group:",
                "    types:",
                "      - checks_requested",
                "  workflow_dispatch:",
                "",
                "permissions:",
                "  actions: read",
                "  contents: read",
                "",
                "concurrency:",
                "  group: ci-${{ github.ref }}",
                "  cancel-in-progress: true",
                "",
                "jobs:",
                "  ci:",
                "    if: ${{ !github.event.repository.private }}",
                "    name: ci / matrix",
                "    uses: swift-institute/.github/.github/workflows/swift-ci.yml@main",
            ].joined(separator: "\n") + "\n"
        }
    }
}
