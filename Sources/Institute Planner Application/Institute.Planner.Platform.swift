public import Institute_Model

extension Institute.Planner {
    /// A platform the planner is published for, spelled as its assets
    /// and rows spell it.
    public enum Platform: Swift.String, CaseIterable, Hashable, Sendable {
        case linux = "linux-x86_64"
        case macos = "macos-arm64"
    }
}
