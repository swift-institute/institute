import Command
import Institute_GitHub_Application
import Institute_Model
import Institute_Workspace_Application
import Testing

@testable import Institute_Application

/// Parses one argv through the typed router, exactly as `main.swift` does.
private func parse(
    _ argv: [Swift.String]
) throws -> Institute.Application.CLI {
    try Command.parse(Institute.Application.CLI.self, from: argv, initial: .sync(.init()))
}

@Suite
struct `Institute Application CLI GitHub Tests` {

    // The minting mechanism itself lives in swift-github as the 'GitHub App'
    // product (TX-APP1A) and is tested there; what remains here is the CLI
    // surface that composes it.

    @Test
    func `accepts github token with an organization`() throws {
        let command = try parse(["github", "token", "--org", "swift-primitives"])

        guard case .github(.token(let token)) = command else {
            Issue.record("expected github token, got \(command)")
            return
        }
        #expect(token.organization == "swift-primitives")
    }

    @Test
    func `requires an organization for github token`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["github", "token"])
        }
    }

    @Test
    func `requires the token mode after github`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["github", "--org", "swift-primitives"])
        }
    }

    @Test
    func `rejects credential flags outside github token`() {
        // A credential flag silently ignored mints a *wider* token than the
        // caller asked for, and nothing downstream can tell the difference.
        #expect(throws: Command.Error.self) {
            _ = try parse(["doctor", "--permission", "contents=read"])
        }
        #expect(throws: Command.Error.self) {
            _ = try parse(["sync", "--org", "swift-primitives"])
        }
    }

    @Test
    func `narrows the minted token by repeated permissions`() throws {
        let command = try parse([
            "github", "token",
            "--org", "swift-primitives",
            "--permission", "contents=read",
            "--permission", "metadata=read",
        ])

        guard case .github(.token(let token)) = command else {
            Issue.record("expected github token, got \(command)")
            return
        }
        #expect(token.permissions == ["contents=read", "metadata=read"])
    }
}
