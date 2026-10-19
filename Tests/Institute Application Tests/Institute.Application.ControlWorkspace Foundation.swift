import Foundation

enum ControlWorkspaceFoundation {
    /// The committed control workspace's `contents.xcworkspacedata`, read as
    /// UTF-8 from the repository root three levels above `filePath`.
    static func contents(besideTestFile filePath: Swift.String) throws -> Swift.String {
        let root = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()  // Institute Application Tests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
        let workspace =
            root
            .appendingPathComponent("institute control.xcworkspace")
            .appendingPathComponent("contents.xcworkspacedata")
        // A Windows checkout converts the committed LF to CRLF; compare the
        // committed bytes, not the platform's text conversion of them.
        return try String(contentsOf: workspace, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }
}
