public import File_System
public import Institute_Model

extension Institute.Repository.Policy {
    public enum ToolState {}
}

extension Institute.Repository.Policy.ToolState {
    public static let directory: File.Directory = .init(".swiftpm")

    public static func findings(in tracked: [Swift.String]) -> [Swift.String] {
        tracked.filter { path in
            path.split(separator: "/", omittingEmptySubsequences: true).dropLast().contains { $0 == Self.directory.path.string }
        }
        .sorted()
    }

    // swift-linter:disable:next raw concept
    // REASON: a tracked entry as the git index lists it, only quoted back; git admits names with control characters, which File.Path refuses, and such a file must still be reported.
    public static func message(_ path: Swift.String) -> Swift.String {
        "`\(path)` is SwiftPM and Xcode tool state: a shared scheme here appears in every workspace that depends on "
            + "this package and can become its active scheme (swift-compositions/swift-sqlite#2). Untrack it; a test "
            + "timeout is a Swift Testing `.timeLimit` trait, not a test plan."
    }
}
