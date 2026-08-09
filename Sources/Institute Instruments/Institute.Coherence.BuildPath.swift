public import Institute_Model
internal import Institute_Inventory
internal import Institute_Development
internal import Institute_Doctor
internal import Institute_Lint

public import Command

extension Institute.Coherence {
    /// Which build path measures one coherence run.
    ///
    /// `xcodebuildMerged` is Phase 1's calibration scaffolding: the
    /// existing merged `xcodebuild` graph (``Xcode/Build``), forced to
    /// macOS. Per the standing cross-platform mandate (macOS-only
    /// tooling is a blocker), ``swiftPMComposedRoot`` is the
    /// mandate-required end state — a synthetic root package
    /// (``Institute/Composed``) whose `.package(path:)` dependencies span
    /// the selection, built with `swift build` through
    /// ``Build/Coordinator``: no Xcode, no workspace bundle, runnable on
    /// Ubuntu. Selectable so Phase 1 stays available for calibration
    /// alongside it (swift-institute/institute-application#80, #81).
    ///
    /// The raw value is exactly the string the receipt's
    /// `instrument.buildPath` field records, so a receipt and the
    /// build path that produced it never need a second mapping.
    public enum BuildPath: Swift.String, Swift.CaseIterable, Equatable, Sendable, Argument.Codable {
        case xcodebuildMerged = "xcodebuild-merged"
        case swiftPMComposedRoot = "swiftpm-composed-root"

        public init?(argument: Swift.String) {
            self.init(rawValue: argument)
        }

        public var argumentDescription: Swift.String { rawValue }
    }
}
